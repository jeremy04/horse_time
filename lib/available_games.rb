require 'mechanize'
require 'json'
require 'active_support/all'

class AvailableGames
  def self.games
    agent = Mechanize.new
    page = agent.get("http://www.nicetimeonice.com/api/seasons/20152016/games/")
    json = JSON.parse(page.content)
    games = json.select { |h| Date.parse(h["date"]) == (Time.now.utc + Time.zone_offset("-10")).to_date }.map {|x| [x["homeTeam"],x["awayTeam"]] }.sort
    games
  end
end