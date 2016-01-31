require 'mechanize'
require 'active_support/all'
require 'sinatra/contrib/all'
require 'nokogiri'
require 'json'

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