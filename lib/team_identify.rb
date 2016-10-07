require 'mechanize'
require 'json'
require 'nokogiri'
require 'active_support/all'

class TeamIdentify
  attr_reader :other_team

  def initialize(horse_team, date=Time.now)
    @horse_team = horse_team
    @agent = Mechanize.new{|a| a.ssl_version, a.verify_mode = :TLSv1_2, OpenSSL::SSL::VERIFY_NONE}
    @date = date
  end

  def determine_team
    json = JSON.parse(File.read("schedule.json"))

    # Get latest game
    latest_game = horse_games(json).select { |h| Date.parse(h["date"]) == (@date.utc + Time.zone_offset("-10")).to_date }.first

    team = determine_other_team(latest_game)
    @other_team = team
    [get_link(@horse_team), get_link(team)]
  end

  private 

  def horse_games(json)
    json.select { |x| x["awayTeam"] == @horse_team || x["homeTeam"] == @horse_team }
  end

  def get_link(team)
    page = @agent.get("http://www2.dailyfaceoff.com/teams/")
    doc = Nokogiri::HTML(page.body)
    link = doc.css("#matchups_container a").map { |x| x.attributes["href"].value }.select { |x| x =~ /#{team.gsub(/\W/," ").squish.gsub(" ", "-").downcase}/  }
    "http://www2.dailyfaceoff.com/#{link.first}"
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
