require 'mechanize'
require 'json'
require 'nokogiri'

class ActiveRoster
  def initialize(horse_team)
    @horse_team = horse_team
  end

  def scrape
    agent = Mechanize.new
    page = agent.get("http://www.nicetimeonice.com/api/seasons/20152016/games/")
    json = JSON.parse(page.content)
    json = json.select { |x| x["awayTeam"] == @horse_team || x["homeTeam"] == @horse_team }
    latest_game = horse_games(json).sort_by { |h| Date.parse(h["date"]) }.last
    
    begin
      agent = Mechanize.new
      page = agent.get("https://statsapi.web.nhl.com/api/v1/game/#{latest_game["gameID"]}/feed/live?site=en_nhl")
    rescue Mechanize::ResponseCodeError => e
      return {:horse_team => [], :other => [] }
    end

    jsonData = JSON.parse(page.body)
    players = jsonData["gameData"]["players"].map { |p| p[1] }
    if players.size > 0
      home_skaters = players.select { |p| p["currentTeam"]["name"] == latest_game["homeTeam"] }.map { |p| p["fullName"] }
      away_skaters = players.select { |p| p["currentTeam"]["name"] == latest_game["awayTeam"] }.map { |p| p["fullName"] }

    else
      home_team_id = jsonData["gameData"]["teams"]["home"]["id"]
      away_team_id = jsonData["gameData"]["teams"]["away"]["id"]
      begin
        agent = Mechanize.new
        page = agent.get("https://statsapi.web.nhl.com/api/v1/teams?site=en_nhl&teamId=#{home_team_id},#{away_team_id}&expand=team.roster,roster.person,person.stats&stats=statsSingleSeason")
      rescue Mechanize::ResponseCodeError => e
        return {:horse_team => [], :other => [] }
      end

      jsonData = JSON.parse(page.body)
      home_skaters = jsonData["teams"][0]["roster"]["roster"].map { |p| p["person"]["fullName"] }
      away_skaters = jsonData["teams"][1]["roster"]["roster"].map { |p| p["person"]["fullName"] }
    end

    if latest_game["homeTeam"] == @horse_team
      return { :horse_team => home_skaters, :other => away_skaters }
    else
      return { :horse_team => away_skaters, :other => home_skaters }
    end

  end

  private

  def horse_games(json)
    json.select { |x| x["awayTeam"] == @horse_team || x["homeTeam"] == @horse_team }
  end
end
