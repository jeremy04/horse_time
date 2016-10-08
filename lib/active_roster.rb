require 'mechanize'
require 'json'
require 'nokogiri'
require './lib/team_identify'
require './lib/team_scrapper'

class ActiveRoster
  def initialize(horse_team, date=Time.now)
    @horse_team = horse_team
    @date = date
  end

  def active_roster
    json = JSON.parse(File.read("schedule.json"))
    json = json.select { |x| x["awayTeam"] == @horse_team || x["homeTeam"] == @horse_team }
    latest_game = horse_games(json).select { |h| Date.parse(h["date"]) == (@date.utc + Time.zone_offset("-10")).to_date }.first
    
    begin
      agent = Mechanize.new{|a| a.ssl_version, a.verify_mode = :TLSv1_2, OpenSSL::SSL::VERIFY_NONE}
      puts "Getting team ids: https://statsapi.web.nhl.com/api/v1/game/#{latest_game["gameID"]}/feed/live?site=en_nhl"
      page = agent.get("https://statsapi.web.nhl.com/api/v1/game/#{latest_game["gameID"]}/feed/live?site=en_nhl")
    rescue Mechanize::ResponseCodeError => e
      return {:horse_team => [], :other_team => [] }
    end

    jsonData = JSON.parse(page.body)
    players = jsonData["gameData"]["players"].map { |p| p[1] }
    if players.size > 0
      home_skaters = players.select { |p| p["currentTeam"] && p["currentTeam"]["name"] == latest_game["homeTeam"] }.map { |p| p["fullName"] }
      away_skaters = players.select { |p| p["currentTeam"] && p["currentTeam"]["name"] == latest_game["awayTeam"] }.map { |p| p["fullName"] }
    else
      home_team_id = jsonData["gameData"]["teams"]["home"]["id"]
      away_team_id = jsonData["gameData"]["teams"]["away"]["id"]
      
      begin
        agent = Mechanize.new{|a| a.ssl_version, a.verify_mode = :TLSv1_2, OpenSSL::SSL::VERIFY_NONE}
        puts "Getting roster https://statsapi.web.nhl.com/api/v1/teams?site=en_nhl&teamId=#{home_team_id},#{away_team_id}&expand=team.roster,roster.person,person.stats&stats=statsSingleSeason"
        page = agent.get("https://statsapi.web.nhl.com/api/v1/teams?site=en_nhl&teamId=#{home_team_id},#{away_team_id}&expand=team.roster,roster.person,person.stats&stats=statsSingleSeason")
      rescue Mechanize::ResponseCodeError => e
        return {:horse_team => [], :other_team => [] }
      end

      jsonData = JSON.parse(page.body)

      home_skaters = jsonData["teams"].select { |team| team["id"] == home_team_id }.first["roster"]["roster"].select { |p| p["person"]["primaryPosition"]["code"] != "G" && p["person"]["rosterStatus"] != "I" }.map { |p| p["person"]["fullName"] }
      away_skaters = jsonData["teams"].select { |team| team["id"] == away_team_id }.first["roster"]["roster"].select { |p| p["person"]["primaryPosition"]["code"] != "G" && p["person"]["rosterStatus"] != "I" }.map { |p| p["person"]["fullName"] }
    end


    i = TeamIdentify.new(@horse_team)
    horse_link, other_link = i.determine_team

    s = TeamScrapper.new
    s.visit_roster(horse_link)
    horse_lines = s.scrape_players[:players]

    s2 = TeamScrapper.new
    s2.visit_roster(other_link)
    other_lines = s2.scrape_players[:players]

    if latest_game["homeTeam"] == @horse_team
      return { :horse_team => home_skaters & horse_lines, :other_team => away_skaters & other_lines }
    else
      return { :horse_team => away_skaters & other_lines, :other_team => home_skaters & horse_lines  }
    end

  end

  private

  def horse_games(json)
    json.select { |x| x["awayTeam"] == @horse_team || x["homeTeam"] == @horse_team }
  end
end
