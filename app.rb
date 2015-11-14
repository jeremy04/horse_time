# A Sinatra app for displaying one's resume in multiple formats
require 'rubygems'
require 'sinatra'

get '/' do
  send_file 'index.html'
end

