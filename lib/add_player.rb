require 'uri'
require 'redis'
require 'pp'
require 'json'
uri = URI.parse(ENV["REDISCLOUD_URL"] || "http://127.0.0.1:6379")
REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

room_code = ARGV[0]
player = ARGV[1]


if player.nil? || room_code.nil?
  puts "Invalid args, nothing passed in"
  exit 1
end
puts "REDIS URL: #{ENV["REDISCLOUD_URL"]}"

players = JSON.parse(REDIS.hget(room_code, "players") || "[]")
if players.size > 0
  horse_team = []
  other_team = []

  2.times do
    puts "Enter horse_team player:"
    scratch = $stdin.gets
    scratch = scratch.chomp
    horse_team << scratch
  end

  2.times do
    puts "Enter other_team player:"
    scratch = $stdin.gets
    scratch = scratch.chomp
    other_team << scratch
  end

  entry =  {"name"=> player, "status" => "new", "horses" => {"other_team" => other_team, "horse_team" => horse_team}}
  puts entry
  players << entry
  
  if other_team.size > 0 && horse_team.size > 0
    REDIS.hset(room_code, "players", JSON.dump(players))
    pickCount = REDIS.hget(room_code, "pickCount")
    REDIS.hset(room_code, "pickCount", Integer(pickCount) + 4)   
    puts "Updated"
  end
 
end
