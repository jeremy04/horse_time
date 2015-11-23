# A Sinatra app for displaying one's resume in multiple formats
require 'rubygems'
require 'sinatra'
require './team_scrapper'
require 'json'

set :bind, '0.0.0.0'

get '/' do
  send_file 'index.html'
end

get '/scores.json' do
  Scores.new.goals.to_json
end

get '/players.json' do
  content_type :json
  horse = params[:horse] || "Pittsburgh Penguins"

  team_identify = TeamIdentify.new(horse)
  horse_url, other_url = team_identify.determine_team

  scrapper = TeamScrapper.new
  scrapper.visit_roster("http://www2.dailyfaceoff.com#{horse_url}")
  penguins = scrapper.scrape_players

  scrapper = TeamScrapper.new
  scrapper.visit_roster("http://www2.dailyfaceoff.com#{other_url}")
  other_team = scrapper.scrape_players
  {:horse_team => penguins[:players].uniq, :other => other_team[:players].uniq }.to_json
end

get '/random.json' do
  content_type :json
  agent = Mechanize.new
  page = agent.get("http://www.randomserver.dyndns.org/client/random.php?type=LIN&a=0&b=1&n=1")
  pre = page.at '//pre'
  {:random => pre.children.first.text.split("\r\n\r\n").last.strip.to_f }.to_json
end