require 'bundler/setup'
Bundler.setup 
## Just run the application

require './app'

use Faye::RackAdapter, :mount => '/faye', :timeout => 25


run Sinatra::Application