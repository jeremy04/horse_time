# A Sinatra app for displaying one's resume in multiple formats
require 'rubygems'
require 'sinatra'
require './team_scrapper'
require 'json'

get '/' do
  send_file 'index.html'
end

get '/players.json' do
  content_type :json
  scrapper = TeamScrapper.new
  scrapper.visit_roster
  scrapper.scrape_players.to_json
end

get '/random.json' do
  content_type :json
  agent = Mechanize.new
  page = agent.get("http://www.randomserver.dyndns.org/client/random.php?type=LIN&a=0&b=1&n=1")
  pre = page.at '//pre'
  {:random => pre.children.first.text.split("\r\n\r\n").last.strip.to_f }.to_json
end