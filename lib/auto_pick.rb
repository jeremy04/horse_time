# Base

# - Schedule from pick order every job
# - If picked, current job must be removed (manually)
# - If picked, reschedule from time of pick


class AutoPick
  def initialize(redis)
    REDIS = redis
  end

  def create_scheduled_jobs(room_code, pick_order)
    auto_pick_key = "#{room_code}_autopick"  
    unless REDIS.hexists(auto_pick_key)
      REDIS.hset(auto_pick_key, "enabled", "true")
      current_time = Time.now.utc
      pick_order.sort_by { |pick| pick }.map { |player| player[1] }.each do |player|
        current_time += 4.minute
        
        key =  ENV["ATRIGGER_KEY"]
        secret = ENV["ATRIGGER_SECRET"]

        horse_team =  REDIS.hget(room_code, "horse_team")
        create_params = {
           "count" => "1",
           "retries" => "0",
           "url" => "https://horsetime.herokuapp.com/auto_pick.json?room_code=#{room_code}&name=#{player}&game_team=#{horse_team}",
           "timeSlice" => "0minute",
           "first" => current_time.strftime("%Y-%m-%dT%H:%M:%SZ"),
           "tag_key1" => current_time.strftime("%Y-%m-%dT%H:%M:%SZ"),
           "tag_type" => "testing"

        }.to_query

        uri = URI("https://api.atrigger.com/v1/tasks/create?key=#{key}&secret=#{secret}&#{create_params}")
        
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.ssl_version = :TLSv1_2
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        page = http.get(uri.request_uri)
      end
      REDIS.expire(auto_pick_key, 10.hour.to_i)
    end
  end

  def delete_next_scheduled_job(room_code)
    auto_picks = JSON.parse(REDIS.lpop("#{room_code}_autopick"))
    tag_key = DateTime.parse(auto_picks.values.first).strftime("%Y-%m-%dT%H:%M:%SZ")
    key =  ENV["ATRIGGER_KEY"]
    secret = ENV["ATRIGGER_SECRET"]
    delete_params = {
      "tag_key1" => tag_key
    }.to_query

    uri = URI("https://api.atrigger.com/v1/tasks/delete?key=#{key}&secret=#{secret}&#{delete_params}")
          
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.ssl_version = :TLSv1_2
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    page = http.get(uri.request_uri)
  end

end