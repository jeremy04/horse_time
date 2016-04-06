require 'rubygems'
require 'sinatra'
require './lib/scores'
require './lib/active_roster'
require './lib/available_games'
require './lib/pick_order'
require "./lib/rng.rb"
require './lib/players_validator'
require 'json'
require 'sinatra/contrib/all'
require 'active_support/all'
require 'pp'
require './cat_facts'
require 'logger'
require 'active_support/core_ext/hash/indifferent_access'
require 'uri'
require 'net/http'
require 'pubnub'

enable :logging
set :protection, :except => [:json_csrf]
set :bind, '0.0.0.0'

configure do
  require 'uri'
  require 'redis'
  uri = URI.parse(ENV["REDISCLOUD_URL"] || "http://127.0.0.1:6379")
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  puts "Pub nub starting" 
  PUBNUB = Pubnub.new(
    ENV["PUBNUB_PUBKEY"],
    ENV["PUBNUB_SUBKEY"],
    '', #secret key
    '',
    false
  )

end

class RoomCodeValidator

  def self.room_has_players?(room_code)
    REDIS.hget(room_code, "players") && REDIS.hget(room_code, "ready") == "false"
  end

  def self.cookies_match_redis(cookie)
    cookie = cookie || {}.to_json
    room_code = JSON.parse(cookie)["room_code"]
    name      = JSON.parse(cookie)["name"]
    cookie && REDIS.hexists(room_code, "players")
  end

end

def generate_activation_code(size = 4)
  charset = %w{ 2 3 4 6 7 9 A C D E F G H J K M N P Q R T V W X Y Z}
  (0...size).map{ charset.to_a[SecureRandom.random_number(charset.size)] }.join
end

post '/generate_draft.json' do
  content_type :json
  horse_team = params[:horse_team]
  horses_per = params[:horses_per]
  REDIS.hset(params[:room_code], "horse_team", horse_team)
  REDIS.hset(params[:room_code], "horses_per", horses_per.to_i)
  REDIS.hset(params[:room_code], "ready", "true")
  players = JSON.parse(REDIS.hget(params[:room_code], "players")).shuffle(random: SecureRandom::RNG)
  REDIS.hset(params[:room_code], "pickCount", 1);
  REDIS.hset(params[:room_code], "players", JSON.dump(players))
  ["Generated"].to_json
end


get '/auto_pick.json' do 
  content_type :json
  redis_players = REDIS.hget(params[:room_code], "players")
  return { message: "There was an error", errors: ["All parties have left. Try logging out"]}.to_json if redis_players.nil?
  players = JSON.parse(redis_players)
  horses = players.select { |h| h['name'] == params[:name] }.first["horses"]
  horses_picked = players.map { |x| x["horses"].values.flatten }.flatten

  teams_left = horses.keys.select { |k| horses[k].size < 2 }
  roster = Scores.new(params[:game_team]).season_goals

  roster = roster.reject { |h| horses_picked.include?(h["name"]) }

  if teams_left.size > 1
    top_player = roster.sort_by { |x| x["points"] }.last
    selection = top_player["name"]
    horses[top_player["location"]] << selection
  else
    top_player = roster.select { |s| s["location"] == teams_left.first }.sort_by { |x| x["points"] }.last
    selection = top_player["name"]
    horses[teams_left.first] << selection 
  end

  players.each do |player|
    if player["name"] == params[:name]
     player["horses"] = horses 
   end
  end

  horses_per = REDIS.hget(params[:room_code], "horses_per").to_i

  if PlayersValidator.new(players, horses_per).valid?
    REDIS.hset(params[:room_code], "players", JSON.dump(players))
    pickCount = REDIS.hget(params[:room_code], "pickCount").to_i
    pickCount+=1
    REDIS.hset(params[:room_code], "pickCount", pickCount)
    REDIS.hset(params[:room_code], "ready", "over") if pickCount > (players.size * (2 * horses_per ))
    
    #REDIS.lpop("#{params[:room_code]}_autopick") 
    
    PUBNUB.publish({
      "channel" => "horse_selected",
      "message" => { "player" => params[:name],
                     "horse" => selection
                   },
      "callback" => lambda do |message| puts message end
    })

    { message: "Updated sucessfully" , errors: []}.to_json
  else
    { message: "There was an error", errors: ["Cant pick the same guy twice bro"]}.to_json
  end
end


post '/update_pick.json' do 
  content_type :json
  redis_players = REDIS.hget(params[:room_code], "players")
  return { message: "There was an error", errors: ["All parties have left. Try logging out"]}.to_json if redis_players.nil?
  players = JSON.parse(redis_players)
  horses = players.select { |h| h['name'] == params[:name] }.first["horses"]
  horses["horse_team"] << params[:horse_team] if params[:horse_team]
  horses["other_team"] << params[:other_team] if params[:other_team]
  players.each do |player|
    if player["name"] == params[:name]
     player["horses"] = horses 
   end
  end


  horses_per = REDIS.hget(params[:room_code], "horses_per").to_i
  if PlayersValidator.new(players, horses_per).valid?

    # auto_pick = AutoPick.new(REDIS)
    # auto_pick.delete_next_scheduled_job(params[:room_code])

    REDIS.hset(params[:room_code], "players", JSON.dump(players))
    pickCount = REDIS.hget(params[:room_code], "pickCount").to_i
    pickCount+=1
    REDIS.hset(params[:room_code], "pickCount", pickCount)
    REDIS.hset(params[:room_code], "ready", "over") if pickCount > (players.size * (2 * horses_per )) 
    { message: "Updated sucessfully" , errors: []}.to_json
  else
    { message: "There was an error", errors: ["Cant pick the same guy twice bro"]}.to_json
  end
end


get '/get_players.json' do
  content_type :json
  players = JSON.parse(REDIS.hget(params[:room_code], "players"))
  count = REDIS.hget(params[:room_code], "pickCount").to_i
  {"players"=> players, "pickCount" => count }.to_json
end

post '/login' do
  params[:room_code] = params[:room_code].upcase
  if params[:name].present? && params[:room_code].present? && RoomCodeValidator.room_has_players?(params[:room_code])
    players = JSON.parse(REDIS.hget(params[:room_code], "players"))
    players = players.map { |p| p.with_indifferent_access }
    params[:name] = params[:name].gsub(/\s/,"")
    players <<  { name: params[:name], status: 'new',
                  horses: { horse_team: [], other_team: [] }
                }
    if players.size == 1
      REDIS.hset(params[:room_code], "room_manager", params[:name])
    end
    
    return "Someone with that name is already logged in" if players.uniq { |p| p[:name] }.size != players.size
    players = players.uniq { |p| p[:name] }

    REDIS.hset(params[:room_code], "players", JSON.dump(players) )
    cookie_info = { room_code: params[:room_code], name: params[:name] }
    response.set_cookie "horsetime", { value: JSON.dump(cookie_info), max_age: 5 * 60 * 60 }
  else
    return "Fail Whale: La sala no existe o juego ha comenzado. Lo siento, amigo."
  end
  redirect to('/')
end

post "/logout" do
  name = JSON.parse(cookies[:horsetime])["name"]
  room_code = JSON.parse(cookies[:horsetime])["room_code"]
  redis_players = REDIS.hget(room_code, "players")

  # Manager left 
  if redis_players.nil?
    response.delete_cookie "horsetime"
    redirect "/"
  end

  players = JSON.parse(redis_players)

  players = players.map do |player|
    player["status"] = "inactive" if player["name"] == name
    player
  end

  REDIS.hset(room_code, "players", JSON.dump(players))
  
  if name == REDIS.hget(room_code, "room_manager")
    REDIS.del room_code
  end

  response.delete_cookie "horsetime"
  redirect "/"
end


get %r{/room/([A-Z0-9]{4})} do
  if RoomCodeValidator.cookies_match_redis(cookies[:horsetime])
    @room_code = JSON.parse(cookies[:horsetime])["room_code"]
    @manager = REDIS.hget(@room_code, "room_manager")
    @user = JSON.parse(cookies[:horsetime])["name"]
    players = REDIS.hget(@room_code, "players")
    @players = JSON.parse(players).select { |p| p["status"] != 'inactive' }.map { |p| p["name"] }
    @teams = AvailableGames.games
    if REDIS.hget(@room_code, "ready") == "false"
      erb :lobby
    elsif REDIS.hget(@room_code, "ready") == "true" || REDIS.hget(@room_code, "ready") == "over"
      @draft_over = REDIS.hget(@room_code, "ready") == "over"
      @pick_count = REDIS.hget(@room_code, "pickCount")
      @horses_per = REDIS.hget(@room_code, "horses_per").to_i
      rounds = @horses_per * 2
      pick_order = PickOrder.new(@players, rounds)
      @pick_order = pick_order.generate_pick_order

      # auto_pick = AutoPick.new(REDIS)
      # auto_pick.create_scheduled_jobs(@room_code, @pick_order)

      @roster = JSON.parse(players).select { |p| p["status"] != 'inactive' }.map { |acc, h| { acc["name"] => acc["horses"] } }.reduce(:merge)
      team_playing =  @teams.select { |team| team.first == REDIS.hget(@room_code, "horse_team") }.first
      if team_playing
        @horse_team = team_playing.first
        @other_team = team_playing[1]
      else
        @horse_team = "Pittsburgh Penguins"
        @other_team = "Heroku sucks at time"
      end
      erb :room
    end
  else
    redirect "/login"
  end
end

get "/login" do
  if RoomCodeValidator.cookies_match_redis(cookies[:horsetime])
    room_code = JSON.parse(cookies[:horsetime])["room_code"]
    redirect "/room/#{room_code}"
  else
    @room_code = params[:room_code]
    matches = REDIS.scan 0, match: "[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]"
    matches = matches.flatten.select { |s| s =~ /[A-Z0-9]{4}/}
    @public_rooms = matches
    erb :login
  end
end

get '/exception' do
  raise Exception, "Hi Rollbar"
end

get '/' do
  if cookies[:horsetime]
    room_code = JSON.parse(cookies[:horsetime])["room_code"]
    redirect "/room/#{room_code}"
  else
    redirect "/login?#{params[:room_code]}"
  end
end

post '/generate_room_code.json' do
  content_type :json
  activation_code = generate_activation_code
  REDIS.hset(activation_code, "players", JSON.dump([]))
  REDIS.hset(activation_code, "ready", false)
  REDIS.expire(activation_code, 5 * 60 * 60)
  {:room_code => activation_code}.to_json
end

class CacheWrapper
  attr_accessor :ttl
  
  def initialize(horse_team, room_code)
    @horse_team = horse_team
    @room_code = room_code
    @ttl = 5.hour.to_i
  end

  def get_cached(model, cache_key)
    if @room_code && REDIS.hexists(@horse_team.gsub(/\s/,"")  + "_" + @room_code, cache_key)
      pp "Roster cached: #{@horse_team} #{@room_code}"
      return REDIS.hget(@horse_team.gsub(/\s/,"")  + "_" + @room_code, cache_key)
    else
      pp "HIT!!"
      roster = model.send(cache_key.to_sym)
      if @room_code
        REDIS.hset(@horse_team.gsub(/\s/,"") + "_" + @room_code, cache_key, JSON.dump(roster))
        REDIS.expire(@horse_team.gsub(/\s/,"") + "_" + @room_code, @ttl)
      end
      return roster.to_json
    end
  end
end

get '/season_stats.json' do
  content_type :json
  horse_team = params[:horse_team] || "Pittsburgh Penguins"
  room_code = params[:room_code]

  wrapper = CacheWrapper.new(horse_team, room_code)
  season_stats = JSON.parse(wrapper.get_cached(Scores.new(horse_team), "season_goals"))
  active_roster = JSON.parse(wrapper.get_cached(ActiveRoster.new(horse_team), "active_roster"))
  season_stats.select { |player| active_roster[player["location"]].include?(player["name"]) }.to_json
end

get '/scores.json' do
  content_type :json
  horse_team = params[:horse_team] || "Pittsburgh Penguins"
  room_code = params[:room_code]
  wrapper = CacheWrapper.new(horse_team, room_code)
  wrapper.ttl = 8.seconds.to_i
  wrapper.get_cached(Scores.new(horse_team), "goals")
end

get '/random.json' do
  content_type :json
  agent = Mechanize.new
  page = agent.get("http://www.randomserver.dyndns.org/client/random.php?type=LIN&a=0&b=1&n=1")
  pre = page.at '//pre'
  {:random => pre.children.first.text.split("\r\n\r\n").last.strip.to_f }.to_json
end

get '/cat_fact' do
  "#{CatFacts.new.random_fact}"
end

get '/ATriggerVerify.txt' do
  send_file 'ATriggerVerify.txt'
end

get '/flux' do
  send_file 'flux.html'
end
