require "rubygems"
require "sinatra"
require "./lib/cache_wrapper"
require "./lib/scores"
require "./lib/active_roster"
require "./lib/auto_pick_time"
require "./lib/available_games"
require "./lib/pick_order"
require "./lib/rng.rb"
require "./lib/players_validator"
require "json"
require "active_support/all"
require "pp"
require "./cat_facts"
require "logger"
require "active_support/core_ext/hash/indifferent_access"
require "uri"
require "net/http"
require "pubnub"
require "httparty"

if ENV['RACK_ENV'] != 'production'
  require 'dotenv'
  Dotenv.load
  require 'pry'
end

enable :logging
set :protection, except: [:json_csrf]
set :bind, "0.0.0.0"

configure do
  require "uri"
  require "redis"
  REDIS = Redis.new(url: ENV["REDISTOGO_URL"])
  puts "Pub nub starting"
  PUBNUB = Pubnub.new(
    subscribe_key: ENV["PUBNUB_SUBKEY"],
    publish_key:   ENV["PUBNUB_PUBKEY"],
    uuid:          '5ab58262-66c8-4eea-a2eb-75ed2d14661b'
  )
  def cookies
    request.cookies.with_indifferent_access
  end
end

class RoomCodeValidator
  def self.room_has_players?(room_code)
    REDIS.hget(room_code, "players") && REDIS.hget(room_code, "ready") == "false"
  end

  def self.cookies_match_redis(cookie)
    cookie ||= {}.to_json
    room_code = JSON.parse(cookie)["room_code"]
    cookie && REDIS.hexists(room_code, "players")
  end
end

def generate_activation_code(size=4)
  charset = %w( 2 3 4 6 7 9 A C D E F G H J K M N P Q R T V W X Y Z )
  (0...size).map { charset.to_a[SecureRandom.random_number(charset.size)] }.join
end

post "/generate_draft.json" do
  content_type :json
  horse_team = params[:horse_team]
  horses_per = params[:horses_per]
  REDIS.hset(params[:room_code], "horse_team", horse_team)
  REDIS.hset(params[:room_code], "horses_per", horses_per.to_i)
  REDIS.hset(params[:room_code], "ready", "true")
  players = JSON.parse(REDIS.hget(params[:room_code], "players")).shuffle(random: SecureRandom::RNG)
  REDIS.hset(params[:room_code], "pickCount", 1)
  REDIS.hset(params[:room_code], "players", JSON.dump(players))
  ["Generated"].to_json
end

get "/auto_pick.json" do
  content_type :json
  players = REDIS.hget(params[:room_code], "players")
  return {message: "There was an error", errors: ["All parties have left. Try logging out"]}.to_json if players.nil?
  players = JSON.parse(players)

  horses = players.find {|h| h["name"] == params[:name] }["horses"]
  horses_picked = players.map {|x| x["horses"].values.flatten }.flatten
  horses_per = REDIS.hget(params[:room_code], "horses_per").to_i
  auto_pick_time = AutoPickTime.new(horses_per)
  horses = auto_pick_time.call(horses, horses_picked, params)

  players.each do |player|
    player["horses"] = horses if player["name"] == params[:name]
  end

  horses_per = REDIS.hget(params[:room_code], "horses_per").to_i

  if PlayersValidator.new(players, horses_per).valid?
    REDIS.hset(params[:room_code], "players", JSON.dump(players))
    pickCount = REDIS.hget(params[:room_code], "pickCount").to_i
    pickCount += 1
    REDIS.hset(params[:room_code], "pickCount", pickCount)

    REDIS.hset(params[:room_code], "ready", "over") if pickCount > (players.size * (2 * horses_per))

    PUBNUB.publish("channel"  => "horse_selected",
                   "message"  => {"player" => params[:name],
                                  "over"   => (pickCount > (players.size * (2 * horses_per))),
                                  "horse"  => auto_pick_time.selection.split.map(&:capitalize).join(" ")
    },
                   "callback" => ->(message) do puts message end)

    {message: "Updated sucessfully", errors: []}.to_json
  else
    {message: "There was an error", errors: ["Cant pick the same guy twice bro"]}.to_json
  end
end

post "/update_pick.json" do
  content_type :json
  players = REDIS.hget(params[:room_code], "players")
  return {message: "There was an error", errors: ["All parties have left. Try logging out"]}.to_json if players.nil?
  players = JSON.parse(players)
  horses = players.find {|h| h["name"] == params[:name] }["horses"]
  horses["horse_team"] << params[:horse_team] if params[:horse_team]
  horses["other_team"] << params[:other_team] if params[:other_team]
  players.each do |player|
    player["horses"] = horses if player["name"] == params[:name]
  end

  horses_per = REDIS.hget(params[:room_code], "horses_per").to_i
  if PlayersValidator.new(players, horses_per).valid?

    # auto_pick = AutoPick.new(REDIS)
    # auto_pick.delete_next_scheduled_job(params[:room_code])

    REDIS.hset(params[:room_code], "players", JSON.dump(players))
    pickCount = REDIS.hget(params[:room_code], "pickCount").to_i
    pickCount += 1
    REDIS.hset(params[:room_code], "pickCount", pickCount)
    REDIS.hset(params[:room_code], "ready", "over") if pickCount > (players.size * (2 * horses_per))
    puts "#{params[:name]} picked #{params[:horse_team] || params[:other_team]}"
    {message: "Updated sucessfully", errors: []}.to_json
  else
    {message: "There was an error", errors: ["Cant pick the same guy twice bro"]}.to_json
  end
end

get "/get_players.json" do
  content_type :json
  players = REDIS.hget(params[:room_code], "players") || [].to_s
  players = JSON.parse(players)
  count = REDIS.hget(params[:room_code], "pickCount").to_i
  {"players" => players, "pickCount" => count}.to_json
end

post "/add_scratch_player" do
  params[:room_code] = params[:room_code].upcase
  scratches = JSON.parse(REDIS.hget(params[:room_code], "scratches"))
  scratches << params[:name]
  REDIS.hset(params[:room_code], "scratches", JSON.dump(scratches.uniq))
end

post "/remove_scratch_player" do
  params[:room_code] = params[:room_code].upcase
  scratches = JSON.parse(REDIS.hget(params[:room_code], "scratches"))
  scratches.delete(params[:name])
  REDIS.hset(params[:room_code], "scratches", JSON.dump(scratches.uniq))
end

post "/ghost_player" do
  params[:room_code] = params[:room_code].upcase

  if params[:name].present? && params[:room_code].present?
    players = JSON.parse(REDIS.hget(params[:room_code], "players"))
    players = players.map(&:with_indifferent_access)
    params[:name] = params[:name].gsub(/\W/, "")

    horses = {horse_team: [params[:horse_team_1], params[:horse_team_2]].compact,
              other_team: [params[:other_team_1], params[:other_team_2]].compact}

    picks = horses[:horse_team] + horses[:other_team]

    return "blank" if picks.uniq.size < 4 && params[:scrub]
    return "duplicate" if picks.uniq.size != picks.size

    if picks.any? do |pick|
      players.any? {|p| p[:horses][:horse_team].include?(pick) || p[:horses][:other_team].include?(pick) }
    end
      return "duplicate"
    end

    players << {name: params[:name], status: "new", horses: horses}

    return "error" if players.uniq {|p| p[:name] }.size != players.size
    players = players.uniq {|p| p[:name] }

    REDIS.hset(params[:room_code], "players", JSON.dump(players))
    if params[:scrub]
      pickCount = REDIS.hget(params[:room_code], "pickCount").to_i
      pickCount += 4
      REDIS.hset(params[:room_code], "pickCount", pickCount)
    end
  end
  params[:name]
end

post "/login" do
  params[:room_code] = params[:room_code].upcase
  if params[:name].present? && params[:room_code].present? && RoomCodeValidator.room_has_players?(params[:room_code])
    players = JSON.parse(REDIS.hget(params[:room_code], "players"))
    players = players.map(&:with_indifferent_access)
    params[:name] = params[:name].gsub(/\W/, "")
    players << {name: params[:name], status: "new", horses: {horse_team: [], other_team: []}}
    if players.size == 1
      REDIS.hset(params[:room_code], "room_manager", params[:name])
    end

    return "Someone with that name is already logged in" if players.uniq {|p| p[:name] }.size != players.size
    players = players.uniq {|p| p[:name] }

    REDIS.hset(params[:room_code], "players", JSON.dump(players))
    cookie_info = {room_code: params[:room_code], name: params[:name]}
    response.set_cookie "horsetime", value: JSON.dump(cookie_info), max_age: 5 * 60 * 60
  else
    return "Fail Whale: La sala no existe o juego ha comenzado. Lo siento, amigo."
  end
  redirect to("/")
end

post "/logout" do
  name = JSON.parse(cookies[:horsetime])["name"]
  room_code = JSON.parse(cookies[:horsetime])["room_code"]
  players = REDIS.hget(room_code, "players")

  # Manager left
  if players.nil?
    response.delete_cookie "horsetime"
    redirect "/"
  end

  players = JSON.parse(players)

  players = players.map do |player|
    player["status"] = "inactive" if player["name"] == name
    player
  end

  REDIS.hset(room_code, "players", JSON.dump(players))

  REDIS.del room_code if name == REDIS.hget(room_code, "room_manager")

  response.delete_cookie "horsetime"
  redirect "/"
end

get %r{/room/([A-Z0-9]{4})} do |code|
  pp "current date"
  pp Date.today.to_s
  pp Date.today.to_time.zone
  if RoomCodeValidator.cookies_match_redis(cookies[:horsetime])
    @room_code = JSON.parse(cookies[:horsetime])["room_code"]
    @manager = REDIS.hget(@room_code, "room_manager")
    @user = JSON.parse(cookies[:horsetime])["name"]
    players = REDIS.hget(@room_code, "players")
    @players = JSON.parse(players).select {|p| p["status"] != "inactive" }.map {|p| p["name"] }
    wrapper = CacheWrapper.new("available_games", "games")
    @teams = JSON.parse(wrapper.get_cached(AvailableGames.new, "games"))
    pp "@teams is set to:"
    pp @teams
    @scratches = JSON.parse(REDIS.hget(@room_code, "scratches"))
    @game_over = REDIS.hget(@room_code, "ready") == "over"
    if REDIS.hget(@room_code, "ready") == "false"
      erb :lobby
    elsif REDIS.hget(@room_code, "ready") == "true" || @game_over

      @pick_count = REDIS.hget(@room_code, "pickCount")
      @horses_per = REDIS.hget(@room_code, "horses_per").to_i
      rounds = @horses_per * 2
      pick_order = PickOrder.new(@players, rounds)
      @pick_order = pick_order.generate_pick_order

      @roster = JSON.parse(players).select {|p| p["status"] != "inactive" }.map {|acc, _h| {acc["name"] => acc["horses"]} }.reduce(:merge)
      team_playing = @teams.find {|team| team["home_team"] == REDIS.hget(@room_code, "horse_team") }
      if team_playing
        @horse_team = team_playing["home_team"]
        @other_team = team_playing["away_team"]
      else
        @horse_team = "Pittsburgh Penguins"
        @other_team = "Heroku sucks at time"
      end
      erb :room
    end
  else

    @room_code = code
    @scratches = JSON.parse(REDIS.hget(@room_code, "scratches"))

    if REDIS.hget(@room_code, "ready") == "over"
      @manager = REDIS.hget(@room_code, "room_manager")
      @user = "Guest"
      players = REDIS.hget(@room_code, "players")
      @players = JSON.parse(players).select {|p| p["status"] != "inactive" }.map {|p| p["name"] }

      wrapper = CacheWrapper.new("available_games", "games")
      @teams = JSON.parse(wrapper.get_cached(AvailableGames.new, "games"))
      @pick_count = REDIS.hget(@room_code, "pickCount")
      @horses_per = REDIS.hget(@room_code, "horses_per").to_i
      rounds = @horses_per * 2
      pick_order = PickOrder.new(@players, rounds)
      @pick_order = pick_order.generate_pick_order

      @roster = JSON.parse(players).select {|p| p["status"] != "inactive" }.map {|acc, _h| {acc["name"] => acc["horses"]} }.reduce(:merge)

      team_playing = @teams.find {|team| team["home_team"] == REDIS.hget(@room_code, "horse_team") }
      if team_playing
        @horse_team = team_playing["home_team"]
        @other_team = team_playing["away_team"]
      else
        @horse_team = "Pittsburgh Penguins"
        @other_team = "Heroku sucks at time"
      end
      erb :room
    else
      redirect "/login"
    end
  end
end

get "/login" do
  if RoomCodeValidator.cookies_match_redis(cookies[:horsetime])
    room_code = JSON.parse(cookies[:horsetime])["room_code"]
    redirect "/room/#{room_code}"
  else
    @room_code = params[:room_code]
    matches = REDIS.scan 0, match: "[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]"
    matches = matches.flatten.select {|s| s =~ /[A-Z0-9]{4}/ }
    @public_rooms = matches
    erb :login
  end
end

get "/proxy" do
  puts params[:uri]
  agent = Mechanize.new
  agent.get(CGI.unescape(params[:uri])).body
end

get "/exception" do
  raise Exception, "Hi Rollbar"
end

get "/" do
  if cookies[:horsetime]
    room_code = JSON.parse(cookies[:horsetime])["room_code"]
    redirect "/room/#{room_code}"
  else
    redirect "/login?#{params[:room_code]}"
  end
end

post "/generate_room_code.json" do
  content_type :json
  activation_code = generate_activation_code
  REDIS.hset(activation_code, "players", JSON.dump([]))
  REDIS.hset(activation_code, "scratches", JSON.dump([]))
  REDIS.hset(activation_code, "ready", false)
  REDIS.expire(activation_code, 10.hours.to_i)
  {room_code: activation_code}.to_json
end

get "/season_stats.json" do
  content_type :json
  horse_team = params[:horse_team] || "Pittsburgh Penguins"
  room_code = params[:room_code]

  wrapper = CacheWrapper.new(horse_team, room_code)
  season_stats = JSON.parse(wrapper.get_cached(Scores.new(horse_team), "season_goals"))
  active_roster = JSON.parse(wrapper.get_cached(ActiveRoster.new(horse_team, room_code), "active_roster"))
  season_stats.select {|player| active_roster[player["location"]].include?(player["name"]) }.to_json
end

get "/scores.json" do
  content_type :json
  horse_team = params[:horse_team] || "Pittsburgh Penguins"
  room_code = params[:room_code]
  wrapper = CacheWrapper.new(horse_team, room_code)
  wrapper.ttl = 8.seconds.to_i
  wrapper.get_cached(Scores.new(horse_team), "goals")
end

get "/health" do
  content_type :json
  begin
    REDIS.set("health", Time.now.to_i)
  rescue => Redis::CannotConnectError
    return { health: "ERROR"  }.to_json
  end
  { health: "OK"  }.to_json
end

get "/random.json" do
  content_type :json
  agent = Mechanize.new
  page = agent.get("http://www.randomserver.dyndns.org/client/random.php?type=LIN&a=0&b=1&n=1")
  pre = page.at "//pre"
  {random: pre.children.first.text.split("\r\n\r\n").last.strip.to_f}.to_json
end

get "/cat_fact" do
  "#{CatFacts.new.random_fact}"
end

get "/webrtc" do
  send_file "easy_rtc.html"
end

get "/ATriggerVerify.txt" do
  send_file "ATriggerVerify.txt"
end
