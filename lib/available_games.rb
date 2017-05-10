require 'json'
require 'active_support/all'
require 'net/https'

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
    time = (Time.now.utc + Time.zone_offset("-10")).to_date
    next_day = time + 1.day
    uri = URI("https://statsapi.web.nhl.com/api/v1/schedule?startDate=#{time.strftime("%Y-%m-%d")}&endDate=#{next_day.strftime("%Y-%m-%d")}&expand=schedule.teams,schedule.linescore,schedule.broadcasts.all,schedule.ticket,schedule.game.content.media.epg,schedule.radioBroadcasts,schedule.game.seriesSummary,seriesSummary.series&leaderCategories=&leaderGameTypes=R&site=en_nhl&teamId=&gameType=&timecode=")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.ssl_version = :TLSv1_2
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    page = http.get(uri.request_uri)
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
