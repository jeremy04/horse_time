require 'bundler/setup'
Bundler.setup 
## Just run the application

require './app'
$stdout.sync = true

run Sinatra::Application