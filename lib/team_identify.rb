require 'mechanize'
require 'json'
require 'nokogiri'

class TeamIdentify
  attr_reader :other_team

  def initialize(horse_team)
    @horse_team = horse_team
  end

  def determine_team
    @agent = Mechanize.new
    page = @agent.get("http://www.nicetimeonice.com/api/seasons/20152016/games/")
    json = JSON.parse(page.content)

    # Get latest game
    latest_game = horse_games(json).sort_by { |h| Date.parse(h["date"]) }.last

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
    link = doc.css("#matchups_container a").map { |x| x.attributes["href"].value }.select { |x| x =~ /#{team.gsub(" ","-").downcase}/  }
    link.first
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