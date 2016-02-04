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

players = JSON.parse(REDIS.hget(room_code, "players") || "[]")
if players.size > 0
  index = players.map { |p| p["name"] }.index(player)
  puts "Enter scratched horse:"
  scratch = $stdin.gets
  scratch = scratch.chomp
  

  if players[index]["horses"]["horse_team"].include?(scratch)
    horse_i = players[index]["horses"]["horse_team"].index(scratch)
    puts "Enter new horse:"
    new_player = $stdin.gets
    players[index]["horses"]["horse_team"][horse_i] = new_player.chomp
  elsif players[index]["horses"]["other_team"].include?(scratch)
    horse_i = players[index]["horses"]["other_team"].index(scratch)
    puts "Enter new horse:"
    new_player = $stdin.gets
    players[index]["horses"]["other_team"][horse_i] = new_player.chomp
  else
    puts "IDK MAN"
  end

  if new_player
    REDIS.hset(room_code, "players", JSON.dump(players))
    puts "Updated from #{scratch} to #{new_player}"
  end


else
  puts "No players updated"
end

