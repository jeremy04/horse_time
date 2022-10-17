require 'json'
require 'net/https'
require 'nokogiri'
require './lib/cache_wrapper'
require 'puppeteer-ruby'
require 'cgi'
require 'httparty'
#requires chrome:
# heroku buildpacks:add heroku/google-chrome

class ActiveRoster
  def initialize(horse_team, room_code, date=Time.now)
    @horse_team = horse_team
    @date = date
    @room_code = room_code
  end

  def active_roster
    wrapper = CacheWrapper.new("available_games", "games")
    json = JSON.parse(wrapper.get_cached(AvailableGames.new, "json"))
    json = json.select { |x| x["awayTeam"] == @horse_team || x["homeTeam"] == @horse_team }
    latest_game = horse_games(json).find { |h| Date.parse(h["date"]) == (@date.utc + Time.zone_offset("-10")).to_date }

    puts "Getting team ids: https://statsapi.web.nhl.com/api/v1/game/#{latest_game["gameID"]}/feed/live?site=en_nhl"
    gameData = HTTParty.get("https://statsapi.web.nhl.com/api/v1/game/#{latest_game["gameID"]}/feed/live?site=en_nhl", headers: { 'Content-Type' => 'application/json' })
    players = gameData["gameData"]["players"].map { |p| p[1] }
    home_team_id = gameData["gameData"]["teams"]["home"]["id"]
    away_team_id = gameData["gameData"]["teams"]["away"]["id"]

    if players.size > 0
      home_skaters = players.select { |p| p["currentTeam"] && p["currentTeam"]["name"].tr('é','e') == latest_game["homeTeam"].tr('é','e') }.map { |p| p["fullName"] }
      away_skaters = players.select { |p| p["currentTeam"] && p["currentTeam"]["name"].tr('é','e') == latest_game["awayTeam"].tr('é','e') }.map { |p| p["fullName"] }
    else
      puts "Getting roster https://statsapi.web.nhl.com/api/v1/teams?site=en_nhl&teamId=#{home_team_id},#{away_team_id}&expand=team.roster,roster.person,person.stats&stats=statsSingleSeason"
      teamData = HTTParty.get("https://statsapi.web.nhl.com/api/v1/teams?site=en_nhl&teamId=#{home_team_id},#{away_team_id}&expand=team.roster,roster.person,person.stats&stats=statsSingleSeason", headers: { 'Content-Type' => 'application/json' })
      home_skaters = teamData["teams"].find { |team| team["id"] == home_team_id }["roster"]["roster"].select { |p| p["person"]["primaryPosition"]["code"] != "G" && p["person"]["rosterStatus"] != "I" }.map { |p| p["person"]["fullName"] }
      away_skaters = teamData["teams"].find { |team| team["id"] == away_team_id }["roster"]["roster"].select { |p| p["person"]["primaryPosition"]["code"] != "G" && p["person"]["rosterStatus"] != "I" }.map { |p| p["person"]["fullName"] }
    end

    scratches = JSON.parse(REDIS.hget(@room_code, "scratches")).map { |h| normalize(h) }
    horse_lines = scrape(@horse_team)
    other_lines = scrape(gameData.dig('gameData','teams','away','name'))

    home_skaters = home_skaters.map { |h| normalize(h) }
    horse_lines = horse_lines.map { |h| normalize(h) } - scratches

    away_skaters = away_skaters.map { |h| normalize(h) }
    other_lines = other_lines.map { |h| normalize(h) } - scratches

    if latest_game["homeTeam"] == @horse_team
      pp "NHL API:"
      pp home_skaters
      pp away_skaters

      pp "Daily Faceoff"
      pp horse_lines
      pp other_lines

      return { :horse_team => home_skaters & horse_lines, :other_team => away_skaters & other_lines }
    else
      return { :horse_team => away_skaters & other_lines, :other_team => home_skaters & horse_lines  }
    end
  end

  private

  def scrape(team)
    api_key = ENV['SCRAPEANT_API_KEY']
    team = team.downcase.gsub(/\s/,"-").tr('é','e')
    pp "Scrapping https://dailyfaceoff.com/teams/#{team}/line-combinations/"
    url = CGI.escape("https://dailyfaceoff.com/teams/#{team}/line-combinations/")
    scrape_ant_url = "https://api.scrapingant.com/v2/general?url=#{url}&x-api-key=#{api_key}&proxy_country=US&return_page_source=true"
    response = HTTParty.get(scrape_ant_url)
    if response.success?
      doc = Nokogiri::HTML(response.body)
      forwards = doc.css("#forwards").css(".player-name").map { |name| name.text }
      defense = doc.css("#defense").css(".player-name").map { |name| name.text }

      forwards + defense
    else
      raise "Scrapping failed"
    end
  end

  def normalize(name)
    name.split.join(" ").downcase.gsub(/[^\w\s\-]/,'')
  end

  def horse_games(json)
    json.select { |x| x["awayTeam"] == @horse_team || x["homeTeam"] == @horse_team }
  end
end
