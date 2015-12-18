require 'mechanize'
require 'pp'
require 'chronic'
require 'active_support/all'

class AvailableGames
  def self.games
    agent = Mechanize.new
    page = agent.get("http://www.nicetimeonice.com/api/seasons/20152016/games/")
    json = JSON.parse(page.content)
    games = json.select { |h| Date.parse(h["date"]) == Time.now.to_date }.map {|x| [x["homeTeam"],x["awayTeam"]] }.sort
    games
  end
end

class Scores
  def initialize(horse_team)
    @horse_team = horse_team
  end

  def goals
    agent = Mechanize.new
    page = agent.get("http://www.nicetimeonice.com/api/seasons/20152016/games/")
    json = JSON.parse(page.content)
    json = json.select { |x| x["awayTeam"] == @horse_team || x["homeTeam"] == @horse_team }
    latest_game = horse_games(json).sort_by { |h| Date.parse(h["date"]) }.last
    
    begin
      agent = Mechanize.new
      page = agent.get("http://www.nhl.com/gamecenter/en/icetracker?id=#{latest_game["gameID"]}")
    rescue Mechanize::ResponseCodeError
      return {:goals => [], :assists => [] }
    end
    doc = Nokogiri::HTML(page.body)  
    skaters = doc.css(".skaters tbody tr").children.map { |x| x.text }.each_slice(9).to_a
    goals = skaters.map { |x| [x[1],x[3].to_i] }
    assists =  skaters.map { |x| [x[1],x[4].to_i] }
    foo = {:goals => goals.to_h, :assists => assists.to_h }
    foo
  end
  
  private

  def horse_games(json)
    json.select { |x| x["awayTeam"] == @horse_team || x["homeTeam"] == @horse_team }
  end

end


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

class TeamScrapper
  def visit_roster(link)
    agent = Mechanize.new
    @page = agent.get(link)
  end

  def scrape_players
    active_links = @page.links.find_all.select do |link| 
      not_injuried(link) && active_player_link(link)
    end
    parse_names(active_links)
  end

  private

  def not_injuried(link)
    !(link.attributes.parent.first && (link.attributes.parent.first[1] =~ /IR/ || link.attributes.parent.first[1] =~ /G/)  ) 
  end

  def active_player_link(link)
    link.attributes.first[1] =~ /players\/news/
  end

  def parse_names(links)
    { :players => links.map { |link| link.text.gsub("\n","").gsub("\t","") } }
  end

end
