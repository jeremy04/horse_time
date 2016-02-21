require 'bundler/setup'
Bundler.setup 
## Just run the application
require 'rollbar/middleware/sinatra'
require './app'
$stdout.sync = true

Rollbar.configure do |config|
  config.disable_monkey_patch = true
  config.access_token = ENV['ROLLBAR_ACCESS_TOKEN']
end

use Rollbar::Middleware::Sinatra
run Sinatra::Application
