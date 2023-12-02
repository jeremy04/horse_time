require 'json'
require 'net/https'
require 'nokogiri'
require './lib/cache_wrapper'
require 'active_support/core_ext/hash/indifferent_access'
require 'cgi'
require 'httparty'

class ActiveRoster
  def initialize(horse_team, room_code, date=Time.now)
    @horse_team = horse_team
    @date = date
    @room_code = room_code
    wrapper = CacheWrapper.new("available_games", "games")
    json = JSON.parse(wrapper.get_cached(AvailableGames.new, "games"))

    teams = horse_games(json)
    @other_team = teams["away_team"]

  end

  def active_roster
    scratches = JSON.parse(REDIS.hget(@room_code, "scratches")).map { |h| normalize(h) }
    horse_lines = scrape(@horse_team)
    other_lines = scrape(@other_team)
    horse_lines = horse_lines.map { |h| normalize(h) } - scratches
    other_lines = other_lines.map { |h| normalize(h) } - scratches
    pp "Daily Faceoff"
    pp horse_lines
    pp other_lines

    return { horse_team: horse_lines, other_team: other_lines }.with_indifferent_access
  end

  private

  def scrape(team)
    api_key = ENV['SCRAPEANT_API_KEY']
    team = team.downcase.gsub(/\s/, "-").tr('é', 'e')
    pp "Scraping https://dailyfaceoff.com/teams/#{team}/line-combinations/"
    url = CGI.escape("https://dailyfaceoff.com/teams/#{team}/line-combinations/")
    scrape_ant_url = "https://api.scrapingant.com/v2/general?url=#{url}&x-api-key=#{api_key}&proxy_country=US&return_page_source=true"
    response = HTTParty.get(scrape_ant_url)
    if response.success?
      doc = Nokogiri::HTML(response.body)
      pp "Repsonse body:#{response.body}"

      players = JSON.parse(doc.css("#__NEXT_DATA__").first.text).dig("props", "pageProps", "combinations", "players")
      players = players.reject { |player| player["injuryStatus"] }.map { |x| x["name"].downcase }
      players
    else
      raise "Scraping failed"
    end
  end

  def normalize(name)
    name.split.join(" ").downcase.gsub(/[^\w\s\-]/, '')
  end

  def horse_games(json)
    json.find { |team| team["home_team"] == @horse_team }
  end
end
