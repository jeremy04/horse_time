require './lib/cache_wrapper'
require 'active_support/core_ext/hash/indifferent_access'
require 'nokogiri'
require 'json'
require 'net/https'
require 'uri'
require './lib/player_stats'

class Scores
  def initialize(horse_team, date=Time.now)
    @horse_team = horse_team
    @date = date
    wrapper = CacheWrapper.new("available_games", "games")
    games = JSON.parse(wrapper.get_cached(AvailableGames.new, "games"))
    teams = horse_games(games)
    other_team = teams["away_team"]
    @home_franchise_id = TeamName.get_franchise(@horse_team)
    @away_franchise_id = TeamName.get_franchise(other_team)
    @game_id = teams['game_id']
  end

  def season_goals
    sort = [{"property" => "points", "direction" => "DESC"}].to_json

    home_url = "https://api.nhle.com/stats/rest/en/skater/summary?sort=#{sort}&cayenneExp=franchiseId=#{@home_franchise_id} and gameTypeId=2 and seasonId<=20232024 and seasonId>=20232024"
    home_skaters = HTTParty.get(home_url).dig("data")

    home_skaters = home_skaters.map do |skater|
      [
        ["name", skater["skaterFullName"].downcase],
        ["goals", skater["goals"]],
        ["assists", skater["assists"]],
        ["points", skater["points"]],
        ["location","horse_team"]
      ].to_h.with_indifferent_access
    end

    away_url = "https://api.nhle.com/stats/rest/en/skater/summary?sort=#{sort}&cayenneExp=franchiseId=#{@away_franchise_id} and gameTypeId=2 and seasonId<=20232024 and seasonId>=20232024"
    away_skaters = HTTParty.get(away_url).dig("data")

    away_skaters = away_skaters.map do |skater|
      [
        ["name", skater["skaterFullName"].downcase],
        ["goals", skater["goals"]],
        ["assists", skater["assists"]],
        ["points", skater["points"]],
        ["location","other_team"]
      ].to_h.with_indifferent_access
    end

    # Replace this comment w unit test:
    # [{ "name" => "joe pavelski", "goals" => 0, "assists" => 0, "points" => 0, "location" => "other_team" }]

    points = home_skaters + away_skaters
    points
  end

  def goals
    boxscore =  HTTParty.get("https://api-web.nhle.com/v1/gamecenter/#{@game_id}/boxscore")
    stats = boxscore.dig('boxscore','playerByGameStats').with_indifferent_access
    away_team = stats[:awayTeam].fetch_values(:forwards, :defense, :goalies).flatten
    home_team = stats[:homeTeam].fetch_values(:forwards, :defense, :goalies).flatten
    boxscores = home_team + away_team

    # Replace this comment w unit test:
    # { :goals=>{"t. dellandrea"=>0}, :assists=>{"t. dellandrea"=>0} }

    boxscores.each_with_object({ goals: {}, assists: {} }) do |hash, transformed|
      name = hash["name"]["default"].downcase # Extract and lowercase the name
      transformed[:goals][name] = hash["goals"]
      transformed[:assists][name] = hash["assists"]
    end
  end

  private

  def horse_games(json)
    json.find { |team| team["home_team"] == @horse_team }
  end

  def normalize(name)
    name.split.join(" ").downcase.gsub(/[^\w\s\-]/,'')
  end

end
