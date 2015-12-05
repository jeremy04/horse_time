# A Sinatra app for displaying one's resume in multiple formats
require 'rubygems'
require 'sinatra'
require 'faye'
require './team_scrapper'
require 'json'
require 'securerandom'
require 'sinatra/contrib/all'
require 'active_support/all'
require 'pp'

require "securerandom"

module SecureRandom::RNG
  def self.rand(max)
    SecureRandom.random_number(max)
  end
end

def generate_pick_order(draft_order)
  pick_order = {}
  teams = draft_order.size
  rounds = 4
  total = teams * rounds
  draft_order.each_with_index do |value, index|
    total.times do |i|
      if (teams + 0.5 - ((i) % (2*teams)+1)).abs == teams + 0.5-(index + 1)
        pick_order[i+1] = value
      end
    end
  end
  pick_order
end

set :bind, '0.0.0.0'

configure do
    require 'uri'
    require 'redis'
    uri = URI.parse(ENV["REDISCLOUD_URL"] || "http://127.0.0.1:6379")
    REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
end

def generate_activation_code(size = 4)
  charset = %w{ 2 3 4 6 7 9 A C D E F G H J K M N P Q R T V W X Y Z}
  (0...size).map{ charset.to_a[SecureRandom.random_number(charset.size)] }.join
end

post '/generate_draft.json' do
  content_type :json
  REDIS.hset(params[:room_code], "ready", "true")
  players = JSON.parse(REDIS.hget(params[:room_code], "players")).shuffle(random: SecureRandom::RNG)
  REDIS.hset(params[:room_code], "pickCount", 1);
  REDIS.hset(params[:room_code], "players", JSON.dump(players))
  ["Generated"].to_json
end

post '/update_pick.json' do
  content_type :json
  players = JSON.parse(REDIS.hget(params[:room_code], "players"))
  horses = players.select { |h| h['name'] == params[:name] }.first["horses"]
  horses["horse_team"] << params[:horse_team] if params[:horse_team]
  horses["other_team"] << params[:other_team] if params[:other_team]
  players.each do |player|
    if player["name"] == params[:name]
     player["horses"] = horses 
   end
  end
  REDIS.hset(params[:room_code], "players", JSON.dump(players))
  pickCount = REDIS.hget(params[:room_code], "pickCount").to_i
  pickCount+=1
  REDIS.hset(params[:room_code], "pickCount", pickCount)
  ["Updated"].to_json
end

get '/get_players.json' do
  content_type :json
  players = JSON.parse(REDIS.hget(params[:room_code], "players"))
  count = JSON.parse(REDIS.hget(params[:room_code], "pickCount"))
  {"players"=> players, "pickCount" => count }.to_json
end

post '/login' do
  params[:room_code] = params[:room_code].upcase
  if RoomCodeValidator.room_has_players?(params[:room_code]) || !params[:name].blank? 
    players = JSON.parse(REDIS.hget(params[:room_code], "players"))
    params[:name] = params[:name].gsub(/\s/,"")
    players <<  { name: params[:name], status: 'new',
                  horses: { horse_team: [], other_team: [] }
                }
    if players.size == 1
      REDIS.hset(params[:room_code], "room_manager", params[:name])
    end

    REDIS.hset(params[:room_code], "players", JSON.dump(players) )
    cookie_info = { room_code: params[:room_code], name: params[:name] }
    response.set_cookie "horsetime", { value: JSON.dump(cookie_info), max_age: 5 * 60 * 60 }
  else
    return "Fail Whale: La sala no existe o juego ha comenzado. Lo siento, amigo."
  end
  redirect to('/')
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

post "/leave_lobby" do
  name = JSON.parse(cookies[:horsetime])["name"]
  room_code = JSON.parse(cookies[:horsetime])["room_code"]
  players = JSON.parse(REDIS.hget(room_code, "players"))
  if name == REDIS.hget(room_code, "room_manager")
    REDIS.del room_code
  end
  players = players.map do |player|
    player["status"] = "inactive" if player["name"] == name
    player
  end

  REDIS.hset(room_code, "players", JSON.dump(players))
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
    if REDIS.hget(@room_code, "ready") == "false"
      @page = "lobby"
      erb :lobby
    elsif REDIS.hget(@room_code, "ready") == "true"
      @pick_count = REDIS.hget(@room_code, "pickCount")
      @pick_order = generate_pick_order(@players)
      @roster = JSON.parse(players).map { |acc, h| { acc["name"] => acc["horses"] } }.reduce(:merge)
      erb :room
    else
      @page = "lobby"
      erb :lobby
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
    matches = REDIS.scan 0, match: "[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]"
    matches = matches.flatten.select { |s| s =~ /[A-Z0-9]{4}/}
    @public_rooms = matches
    erb :login
  end
end

get '/' do
  if cookies[:horsetime]
    room_code = JSON.parse(cookies[:horsetime])["room_code"]
    redirect "/room/#{room_code}"
  else
    redirect "/login"
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


get '/scores.json' do
  content_type :json
  horse_team = params[:horse_team] || "Pittsburgh Penguins"
  Scores.new(horse_team).goals.to_json
end

get '/players.json' do
  content_type :json
  horse_team = params[:horse_team] || "Pittsburgh Penguins"

  team_identify = TeamIdentify.new(horse_team)
  horse_url, other_url = team_identify.determine_team

  scrapper = TeamScrapper.new
  scrapper.visit_roster("http://www2.dailyfaceoff.com#{horse_url}")
  penguins = scrapper.scrape_players

  scrapper = TeamScrapper.new
  scrapper.visit_roster("http://www2.dailyfaceoff.com#{other_url}")
  other_team = scrapper.scrape_players
  {:horse_team => penguins[:players].uniq, :other => other_team[:players].uniq }.to_json
end

get '/random.json' do
  content_type :json
  agent = Mechanize.new
  page = agent.get("http://www.randomserver.dyndns.org/client/random.php?type=LIN&a=0&b=1&n=1")
  pre = page.at '//pre'
  {:random => pre.children.first.text.split("\r\n\r\n").last.strip.to_f }.to_json
end