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

