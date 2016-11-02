require "./lib/scores"

class AutoPickTime
  attr_reader :selection

  def call(horses, picked_horses, params)
    teams_left = horses.keys.select { |k| horses[k].size < 2 }
    picked_horses = picked_horses.map { |h| h.downcase }
    wrapper = CacheWrapper.new(params[:game_team], params[:room_code])
    season_stats = JSON.parse(wrapper.get_cached(Scores.new(params[:game_team]), "season_goals"))
    active_roster = JSON.parse(wrapper.get_cached(ActiveRoster.new(params[:game_team]), "active_roster"))
    season_stats = season_stats.select { |player| active_roster[player["location"]].include?(player["name"]) }   
    roster = season_stats.reject { |h| picked_horses.include?(h["name"]) }
    
    if teams_left.size > 1
      top_player = roster.sort_by { |x| [x["points"], x["goals"]] }.last
      @selection = top_player["name"]
      horses[top_player["location"]] << @selection.split.map(&:capitalize).join(' ')
    else
      top_player = roster.select { |s| s["location"] == teams_left.first }.sort_by { |x| [x["points"], x["goals"]] }.last
      @selection = top_player["name"]
      horses[teams_left.first] << @selection.split.map(&:capitalize).join(' ')
    end
    horses
  end
end
