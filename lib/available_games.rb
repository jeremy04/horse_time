require 'mechanize'
require 'json'
require 'active_support/all'

class AvailableGames
  def self.games(date=Time.now)
    json = JSON.parse(File.read("schedule.json"))
    games = json.select { |h| Date.parse(h["date"]) == (date.utc + Time.zone_offset("-10")).to_date }.map {|x| [x["homeTeam"],x["awayTeam"]] }.sort
    games
  end
end