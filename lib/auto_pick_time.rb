require "./lib/scores"

class AutoPickTime
  attr_reader :selection

  def call(horses, picked_horses, params)
    teams_left = horses.keys.select { |k| horses[k].size < 2 }
    roster = Scores.new(params[:game_team]).season_goals    
    roster = roster.reject { |h| picked_horses.include?(h["name"]) }
    if teams_left.size > 1
      top_player = roster.sort_by { |x| x["points"] }.last
      @selection = top_player["name"]
      horses[top_player["location"]] << @selection
    else
      top_player = roster.select { |s| s["location"] == teams_left.first }.sort_by { |x| x["points"] }.last
      @selection = top_player["name"]
      horses[teams_left.first] << @selection 
    end
    horses
  end
end
