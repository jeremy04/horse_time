require 'json'
require 'net/https'
require 'nokogiri'
require './lib/cache_wrapper'
require 'puppeteer-ruby'

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
      home_skaters = players.select { |p| p["currentTeam"] && p["currentTeam"]["name"].tr('é','e') == latest_game["homeTeam"].tr('é','e') }.map { |p| p["fullName"] }
      away_skaters = players.select { |p| p["currentTeam"] && p["currentTeam"]["name"].tr('é','e') == latest_game["awayTeam"].tr('é','e') }.map { |p| p["fullName"] }
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

      home_skaters = jsonData["teams"].find { |team| team["id"] == home_team_id }["roster"]["roster"].select { |p| p["person"]["primaryPosition"]["code"] != "G" && p["person"]["rosterStatus"] != "I" }.map { |p| p["person"]["fullName"] }
      away_skaters = jsonData["teams"].find { |team| team["id"] == away_team_id }["roster"]["roster"].select { |p| p["person"]["primaryPosition"]["code"] != "G" && p["person"]["rosterStatus"] != "I" }.map { |p| p["person"]["fullName"] }
    end


    scratches = JSON.parse(REDIS.hget(@room_code, "scratches")).map { |h| normalize(h) }

    horse_lines = scrape(@horse_team)
    other_lines = scrape(jsonData.dig('gameData','teams','away','name'))

    home_skaters = home_skaters.map { |h| normalize(h) }
    horse_lines = horse_lines.map { |h| normalize(h) } - scratches

    away_skaters = away_skaters.map { |h| normalize(h) }
    other_lines = other_lines.map { |h| normalize(h) } - scratches

    if latest_game["homeTeam"] == @horse_team
      return { :horse_team => home_skaters & horse_lines, :other_team => away_skaters & other_lines }
    else
      return { :horse_team => away_skaters & other_lines, :other_team => home_skaters & horse_lines  }
    end

  end

  private

  def scrape(team)
    options = {
        headless: true,
        slow_mo:  50,
        args: ['--window-size=1280,800']
      }

      Puppeteer.launch **options do |browser|
        page = browser.new_page
        page.viewport = Puppeteer::Viewport.new(width: 1280, height: 800)
        # page.evaluate_on_new_document(<<~JAVASCRIPT)
        # () => {
        #   Object.defineProperty(navigator, "webdriver", {get: () => false});
        #   Object.defineProperty(window, "webdriver", {get: () => false});
        #   window.navigator.chrome = {
        #       runtime: {},
        #   };
        #   Object.defineProperty(navigator, 'platform', {
        #       get: () => "Win32",
        #   });

        #   Object.defineProperty(navigator, 'plugins', {
        #       get: () => [1, 2],
        #   });

        # }
        # JAVASCRIPT
        #page.user_agent = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.39 Safari/537.36"
        page.goto("https://dailyfaceoff.com/teams/#{team.downcase.gsub(/\s/,"-")}/line-combinations/", wait_until: 'domcontentloaded')
        doc = Nokogiri::HTML(page.content)
        forwards = doc.css("#forwards").css(".player-name").map { |name| name.text }
        defense = doc.css("#defense").css(".player-name").map { |name| name.text }
        forwards + defense
      end
  end

  def normalize(name)
    name.split.join(" ").downcase.gsub(/[^\w\s\-]/,'')
  end

  def horse_games(json)
    json.select { |x| x["awayTeam"] == @horse_team || x["homeTeam"] == @horse_team }
  end
end
