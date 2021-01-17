require "net/https"
require "json"
require "nokogiri"
require "active_support/all"
require "./lib/cache_wrapper"
require "./lib/available_games"

class TeamIdentify
  attr_reader :other_team

  def initialize(horse_team, date=Time.now)
    @horse_team = horse_team
    @date = date
    wrapper = CacheWrapper.new("available_games", "games")
    @json = JSON.parse(wrapper.get_cached(AvailableGames.new, "json"))
  end

  def determine_team
    json = @json

    # Get latest game
    latest_game = horse_games(json).find {|h| Date.parse(h["date"]) == (@date.utc + Time.zone_offset("-10")).to_date }
    team = determine_other_team(latest_game)
    @other_team = team
    [get_link(@horse_team), get_link(team)]
  end

  private

  def horse_games(json)
    json.select {|x| x["awayTeam"] == @horse_team || x["homeTeam"] == @horse_team }
  end

  def get_link(team)
    team = team.tr("é", "e")
    team = team.gsub(/\W/, " ").squish.tr(" ", "-").downcase
    "https://www.dailyfaceoff.com/teams/#{team}/line-combinations"
  end

  def determine_other_team(element)
    team = if element["awayTeam"] != @horse_team
             element["awayTeam"]
           else
             element["homeTeam"]
          end
    team
  end
end
