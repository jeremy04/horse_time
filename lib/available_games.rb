require 'mechanize'
require 'json'
require 'active_support/all'
require 'byebug'

class AvailableGames

  attr_reader :json

  def initialize
    @json = json_games
  end

  def games(date=Time.now)
    games = @json.select { |h| Date.parse(h["date"]) == (date.utc + Time.zone_offset("-10")).to_date }.map {|x| [x["homeTeam"],x["awayTeam"]] }.sort
    games
  end

  def json_games
    agent = Mechanize.new{|a| a.ssl_version, a.verify_mode = :TLSv1_2, OpenSSL::SSL::VERIFY_NONE}
    time = (Time.now.utc + Time.zone_offset("-10")).to_date
    next_day = time + 1.day
    page = agent.get("https://statsapi.web.nhl.com/api/v1/schedule?startDate=#{time.strftime("%Y-%m-%d")}&endDate=#{next_day.strftime("%Y-%m-%d")}&expand=schedule.teams,schedule.linescore,schedule.broadcasts.all,schedule.ticket,schedul    e.game.content.media.epg,schedule.radioBroadcasts,schedule.game.seriesSummary,seriesSummary.series&leaderCategories=&leaderGameTypes=R&site=en_nhl&teamId=&gameType=&timecode=")
    json = JSON.parse(page.body).with_indifferent_access
    json = json[:dates].inject([]) do |memo, h| 
      games = h[:games].map do |x|
        { 
          "date" => h[:date],
          "gameID" => x[:gamePk], 
          "awayTeam" => x[:teams][:away][:team][:name], 
          "homeTeam" => x[:teams][:home][:team][:name]
        }
      end
      memo << games
    end.flatten
    json
  end

end
