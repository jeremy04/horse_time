require 'json'
require 'active_support/core_ext/hash/indifferent_access'
require 'net/https'
require 'httparty'
require 'pp'
require './lib/team_name'
require 'active_support/time'


class AvailableGames

  attr_reader :json

  def initialize
  end

  def games
    Time.zone = 'Eastern Time (US & Canada)'
    date = Time.zone.now.to_date.to_s
    api_url = "https://api-web.nhle.com/v1/schedule/#{date}"

    response = HTTParty.get(api_url)

    if response.code == 200
      today_events = response.parsed_response['gameWeek'].select { |game| game['date'] == date }.first['games']
      game_info = today_events.map do |event|
        home_team = TeamName.get_team_name(event.dig('homeTeam','abbrev'))
        away_team = TeamName.get_team_name(event.dig('awayTeam','abbrev'))
        { game_id: event['id'], home_team: home_team, away_team: away_team }.with_indifferent_access
      end

      return game_info
    else
      puts "Failed to fetch data. HTTP Status Code: #{response.code}"
      return []
    end
  end
end
