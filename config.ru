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

warmup do |app|
  unless ENV['LOCAL_HOST']
    require 'ngrok/tunnel'
    options = {port: 4567}
    Ngrok::Tunnel.start(options)
    url = Ngrok::Tunnel.ngrok_url_https
    puts "[NGROK] tunneling at  #{url}"
    puts "[NGROK] Port #{Ngrok::Tunnel.port}"
    puts `heroku config:set LOCAL_HOST=#{url}`
  end
end

use Rollbar::Middleware::Sinatra
run Sinatra::Application
