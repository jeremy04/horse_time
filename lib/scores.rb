require 'mechanize'
require 'active_support/all'
require 'sinatra/contrib/all'
require 'nokogiri'
require 'json'
require 'net/https'
require 'uri'
require './lib/player_stats'

class Scores
  def initialize(horse_team, date=Time.now)
    @horse_team = horse_team
    @date = date
  end

  def season_goals
    json = JSON.parse(File.read("schedule.json"))
    json = json.select { |x| x["awayTeam"] == @horse_team || x["homeTeam"] == @horse_team }
    latest_game = horse_games(json).select { |h| Date.parse(h["date"]) == (@date.utc + Time.zone_offset("-10")).to_date }.first

    uri = URI("https://statsapi.web.nhl.com/api/v1/game/#{latest_game["gameID"]}/feed/live?site=en_nhl")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.ssl_version = :TLSv1_2
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    page = http.get(uri.request_uri)


    jsonData = JSON.parse(page.body)
    home_team_id   = jsonData["gameData"]["teams"]["home"]["id"]
    away_team_id   = jsonData["gameData"]["teams"]["away"]["id"]
    home_team_name = jsonData["gameData"]["teams"]["home"]["name"].gsub('é','e')
    away_team_name = jsonData["gameData"]["teams"]["away"]["name"].gsub('é','e')
   
    uri = URI("https://statsapi.web.nhl.com/api/v1/teams?site=en_nhl&teamId=#{home_team_id},#{away_team_id}&expand=team.roster,roster.person,person.stats&stats=statsSingleSeason")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.ssl_version = :TLSv1_2
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    page = http.get(uri.request_uri)

    jsonData = JSON.parse(page.body)

    home_skaters = jsonData["teams"].select { |team| team["id"] == home_team_id }.first["roster"]["roster"].map { |p| p["person"] }.select { |p| p["primaryPosition"]["code"] != "G" && p["rosterStatus"] != "I" }
    away_skaters = jsonData["teams"].select { |team| team["id"] == away_team_id }.first["roster"]["roster"].map { |p| p["person"] }.select { |p| p["primaryPosition"]["code"] != "G" && p["rosterStatus"] != "I" }

    home_skaters = home_skaters.map { |s| [ ["name", s["fullName"] ] ,["goals", PlayerStats.new(s).goals], ["assists", PlayerStats.new(s).assists], ["points", PlayerStats.new(s).points], ["team", home_team_name], ["location", "horse_team"] ].to_h }
    away_skaters = away_skaters.map { |s| [ ["name", s["fullName"] ] ,["goals", PlayerStats.new(s).goals], ["assists", PlayerStats.new(s).assists], ["points", PlayerStats.new(s).points], ["team", away_team_name], ["location", "other_team"] ].to_h }

    home_skaters = home_skaters.map { |x| x.merge('name' => normalize(x['name']) ) }
    away_skaters = away_skaters.map { |x| x.merge('name' => normalize(x['name']) ) }    

    points = home_skaters + away_skaters
    points
  end

  def goals
    json = JSON.parse(File.read("schedule.json"))
    json = json.select { |x| x["awayTeam"] == @horse_team || x["homeTeam"] == @horse_team }
    latest_game = horse_games(json).select { |h| Date.parse(h["date"]) == (@date.utc + Time.zone_offset("-10")).to_date }.first

    begin
      uri = URI("https://statsapi.web.nhl.com/api/v1/game/#{latest_game["gameID"]}/feed/live?site=en_nhl")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.ssl_version = :TLSv1_2
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      page = http.get(uri.path)
    rescue Mechanize::ResponseCodeError => e
      return {:goals => [], :assists => [] }
    end

    jsonData =  JSON.parse(page.body)
    home_skaters = jsonData["liveData"]["boxscore"]["teams"]["home"]["players"].map { |p| p[1] }
    away_skaters = jsonData["liveData"]["boxscore"]["teams"]["away"]["players"].map { |p| p[1] }

    home_skaters = home_skaters.select { |s|    s["stats"].present? && s["stats"]["skaterStats"].present? }
    home_goals   = home_skaters.map    { |s| [s["person"]["fullName"], s["stats"]["skaterStats"]["goals"]]}
    home_assists = home_skaters.map    { |s| [s["person"]["fullName"], s["stats"]["skaterStats"]["assists"]]}

    away_skaters = away_skaters.select { |s|    s["stats"].present? && s["stats"]["skaterStats"].present? }
    away_goals   = away_skaters.map    { |s| [s["person"]["fullName"], s["stats"]["skaterStats"]["goals"]]}
    away_assists = away_skaters.map    { |s| [s["person"]["fullName"], s["stats"]["skaterStats"]["assists"]]}  


    goals   = home_goals.to_h.merge(away_goals.to_h)
    assists = home_assists.to_h.merge(away_assists.to_h)
  
    foo = {:goals => goals, :assists => assists }
    foo
  end
  
  private

  def horse_games(json)
    json.select { |x| x["awayTeam"] == @horse_team || x["homeTeam"] == @horse_team }
  end

  def normalize(name)
    name.split.join(" ").downcase.gsub(/[^\w\s\-]/,'')
  end

end
