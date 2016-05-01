class CacheWrapper
  attr_accessor :ttl

  def initialize(horse_team, room_code)
    @horse_team = horse_team
    @room_code = room_code
    @ttl = 5.hour.to_i
  end

  def get_cached(model, cache_key)
    if @room_code && REDIS.hexists(cache_key + "_" + @horse_team.gsub(/\s/,"")  + "_" + @room_code, cache_key)
      pp "Roster cached: ##{cache_key} #{@horse_team} #{@room_code}"
      return REDIS.hget(cache_key + "_" + @horse_team.gsub(/\s/,"")  + "_" + @room_code, cache_key)
    else
      pp "Hitting #{cache_key}"
      roster = model.send(cache_key.to_sym)
      if @room_code
        REDIS.hset(cache_key + "_" + @horse_team.gsub(/\s/,"") + "_" + @room_code, cache_key, JSON.dump(roster))
        REDIS.expire(cache_key + "_" + @horse_team.gsub(/\s/,"") + "_" + @room_code, @ttl)
      end
      return roster.to_json
    end
  end
end