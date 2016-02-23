require 'mechanize'
require 'active_support/all'
require 'sinatra/contrib/all'
require 'nokogiri'
require 'json'
require 'net/https'
require 'uri'
require './lib/player_stats'

class Scores
  def initialize(horse_team)
    @horse_team = horse_team
  end

  def season_goals
    agent = Mechanize.new {|a| a.ssl_version, a.verify_mode = :TLSv1_2, OpenSSL::SSL::VERIFY_NONE}
    page = agent.get("http://www.nicetimeonice.com/api/seasons/20152016/games/")
    json = JSON.parse(page.content)
    json = json.select { |x| x["awayTeam"] == @horse_team || x["homeTeam"] == @horse_team }
    latest_game = horse_games(json).sort_by { |h| Date.parse(h["date"]) }.last

    begin
      agent = Mechanize.new {|a| a.ssl_version, a.verify_mode = :TLSv1_2, OpenSSL::SSL::VERIFY_NONE}
      page = agent.get("https://statsapi.web.nhl.com/api/v1/game/#{latest_game["gameID"]}/feed/live?site=en_nhl")
    rescue Mechanize::ResponseCodeError => e
      return {:horse_team => [], :other => [] }
    end

    jsonData = JSON.parse(page.body)
    home_team_id = jsonData["gameData"]["teams"]["home"]["id"]
    away_team_id = jsonData["gameData"]["teams"]["away"]["id"]
    begin
      agent = Mechanize.new {|a| a.ssl_version, a.verify_mode = :TLSv1_2, OpenSSL::SSL::VERIFY_NONE}
      page = agent.get("https://statsapi.web.nhl.com/api/v1/teams?site=en_nhl&teamId=#{home_team_id},#{away_team_id}&expand=team.roster,roster.person,person.stats&stats=statsSingleSeason")
    rescue Mechanize::ResponseCodeError => e
      return {:horse_team => [], :other => [] }
    end

    jsonData = JSON.parse(page.body)

    home_skaters = jsonData["teams"].select { |team| team["id"] == home_team_id }.first["roster"]["roster"].map { |p| p["person"] }.select { |p| p["primaryPosition"]["code"] != "G" && p["rosterStatus"] != "I" }
    away_skaters = jsonData["teams"].select { |team| team["id"] == away_team_id }.first["roster"]["roster"].map { |p| p["person"] }.select { |p| p["primaryPosition"]["code"] != "G" && p["rosterStatus"] != "I" }

    home_skaters = home_skaters.map { |s| [ ["name", s["fullName"] ] , ["points", PlayerStats.new(s).points] ].to_h }
    away_skaters = away_skaters.map { |s| [ ["name", s["fullName"] ] , ["points", PlayerStats.new(s).points] ].to_h }
        
    points = home_skaters + away_skaters
    points
  end

  def goals
    agent = Mechanize.new{|a| a.ssl_version, a.verify_mode = :TLSv1_2, OpenSSL::SSL::VERIFY_NONE}
    page = agent.get("http://www.nicetimeonice.com/api/seasons/20152016/games/")
    json = JSON.parse(page.content)
    json = json.select { |x| x["awayTeam"] == @horse_team || x["homeTeam"] == @horse_team }
    latest_game = horse_games(json).sort_by { |h| Date.parse(h["date"]) }.last


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

end