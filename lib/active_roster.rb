require 'json'
require 'net/https'
require 'nokogiri'
require './lib/team_identify'
require './lib/team_scrapper'
require './lib/cache_wrapper'

class ActiveRoster
  def initialize(horse_team, date=Time.now)
    @horse_team = horse_team
    @date = date
  end

  def active_roster
    wrapper = CacheWrapper.new("available_games", "games")
    json = JSON.parse(wrapper.get_cached(AvailableGames.new, "json"))
    json = json.select { |x| x["awayTeam"] == @horse_team || x["homeTeam"] == @horse_team }
    latest_game = horse_games(json).select { |h| Date.parse(h["date"]) == (@date.utc + Time.zone_offset("-10")).to_date }.first

    uri = URI("https://statsapi.web.nhl.com/api/v1/game/#{latest_game["gameID"]}/feed/live?site=en_nhl")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.ssl_version = :TLSv1_2
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    puts "Getting team ids: https://statsapi.web.nhl.com/api/v1/game/#{latest_game["gameID"]}/feed/live?site=en_nhl"
    page = http.get(uri.request_uri)

    jsonData = JSON.parse(page.body)
    players = jsonData["gameData"]["players"].map { |p| p[1] }

    if players.size > 0
      home_skaters = players.select { |p| p["currentTeam"] && p["currentTeam"]["name"].gsub('é','e') == latest_game["homeTeam"].gsub('é','e') }.map { |p| p["fullName"] }
      away_skaters = players.select { |p| p["currentTeam"] && p["currentTeam"]["name"].gsub('é','e') == latest_game["awayTeam"].gsub('é','e') }.map { |p| p["fullName"] }
    else
      home_team_id = jsonData["gameData"]["teams"]["home"]["id"]
      away_team_id = jsonData["gameData"]["teams"]["away"]["id"]
      
      uri = URI("https://statsapi.web.nhl.com/api/v1/teams?site=en_nhl&teamId=#{home_team_id},#{away_team_id}&expand=team.roster,roster.person,person.stats&stats=statsSingleSeason")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.ssl_version = :TLSv1_2
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      puts "Getting roster https://statsapi.web.nhl.com/api/v1/teams?site=en_nhl&teamId=#{home_team_id},#{away_team_id}&expand=team.roster,roster.person,person.stats&stats=statsSingleSeason"
      page = http.get(uri.request_uri)
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

    home_skaters = home_skaters.map { |h| normalize(h) }
    horse_lines = horse_lines.map { |h| normalize(h) }

    away_skaters = away_skaters.map { |h| normalize(h) }
    other_lines = other_lines.map { |h| normalize(h) }

    if latest_game["homeTeam"] == @horse_team
      return { :horse_team => home_skaters & horse_lines, :other_team => away_skaters & other_lines }
    else
      return { :horse_team => away_skaters & other_lines, :other_team => home_skaters & horse_lines  }
    end

  end

  private

  def normalize(name)
    name.split.join(" ").downcase.gsub(/[^\w\s\-]/,'')
  end

  def horse_games(json)
    json.select { |x| x["awayTeam"] == @horse_team || x["homeTeam"] == @horse_team }
  end
end
