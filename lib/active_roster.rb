require 'mechanize'
require 'json'
require 'nokogiri'

class ActiveRoster
  def initialize(horse_team)
    @horse_team = horse_team
  end
  
  def scrape
    agent = Mechanize.new
    page = agent.get("http://www.nicetimeonice.com/api/seasons/20152016/games/")
    json = JSON.parse(page.content)
    json = json.select { |x| x["awayTeam"] == @horse_team || x["homeTeam"] == @horse_team }
    latest_game = horse_games(json).sort_by { |h| Date.parse(h["date"]) }.last
    
    begin
      agent = Mechanize.new
      page = agent.get("http://www.nhl.com/gamecenter/en/icetracker?id=#{latest_game["gameID"]}")
    rescue Mechanize::ResponseCodeError
      return {:horse_team => [], :other => [] }
    end

    doc = Nokogiri::HTML(page.body)  
    home_skaters = doc.css("#homeTeamScroll .skaters tbody tr").children.map { |x| x.text }.each_slice(9).to_a.map { |x| x[1] }
    away_skaters = doc.css("#awayTeamScroll .skaters tbody tr").children.map { |x| x.text }.each_slice(9).to_a.map { |x| x[1] }

    if latest_game["homeTeam"] == @horse_team
      return { :horse_team => home_skaters, :other => away_skaters }
    else
      return { :horse_team => away_skaters, :other => home_skaters }
    end

  end

  private

  def horse_games(json)
    json.select { |x| x["awayTeam"] == @horse_team || x["homeTeam"] == @horse_team }
  end
end