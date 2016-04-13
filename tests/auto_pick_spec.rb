require_relative '../lib/auto_pick_time'
require 'minitest/autorun'
require 'pp'

describe AutoPickTime do

  before do
    @season_goals = [
        {"name" => "Claude Giroux",
         "points" => 67,
         "team" => "Philadelphia Flyers",
         "location" => "horse_team"},
        {"name" => "Wayne Simmonds",
         "points" => 60,
         "team" => "Philadelphia Flyers",
         "location" => "horse_team"},
        {"name" => "Brayden Schenn",
          "points" => 59,
          "team" => "Philadelphia Flyers",
          "location" => "horse_team"},
        {"name" => "Matt Read",
          "points" => 26,
          "team" => "Philadelphia Flyers",
          "location" => "horse_team"},
        {"name" => "Radko Gudas",
          "points" => 14,
          "team" => "Philadelphia Flyers",
          "location" => "horse_team"},

        {"name" => "Sidney Crosby",
         "points" => 85,
         "team" => "Pittsburgh Penguins",
         "location" => "other_team"},
        {"name" => "Kris Letang",
          "points" => 67,
          "team" => "Pittsburgh Peguins",
          "location" => "other_team"},
        {"name" => "Phil Kessel",
          "points" => 59,
          "team" => "Pittsburgh Penguins",
          "location" => "other_team"},
        {"name" => "Evgeni Malkin",
          "points" => 58,
          "team" => "Pittsburgh Penguins",
          "location" => "other_team"},
        {"name" => "Chris Kunitz",
          "points" => 40,
          "team" => "Pittsburgh Penguins",
          "location" => "other_team"},
      ]
  end

  describe "call" do
    it "Player 1: First pick should be highest points player" do

      horses = {"horse_team" => [], "other_team" => [] }
      picked_horses = []
  
      scores = Minitest::Mock.new

  
      scores.expect :season_goals, @season_goals 
      params = {:game_team => "Philadelphia Flyers"}

      Scores.stub :new, scores do
        AutoPickTime.call(horses, picked_horses, params).must_equal({"horse_team"=>[], "other_team"=>["Sidney Crosby"]})
      end
    end

    it "Player 2: First pick should be highest points player" do

      horses = {"horse_team" => [], "other_team" => [] }
      picked_horses = [
                        "Sidney Crosby",
                     ]
  
      scores = Minitest::Mock.new

  
      scores.expect :season_goals, @season_goals 
      params = {:game_team => "Philadelphia Flyers"}

      Scores.stub :new, scores do
        AutoPickTime.call(horses, picked_horses, params).must_equal({"horse_team"=>["Claude Giroux"], "other_team"=>[]})
      end
    end

    it "Player 2: Second pick should be highest points player" do

      horses = {"horse_team" => ["Claude Giroux"], "other_team" => [] }
      picked_horses = [
                        "Claude Giroux",
                        "Sidney Crosby",
                     ]
  
      scores = Minitest::Mock.new

  
      scores.expect :season_goals, @season_goals 
      params = {:game_team => "Philadelphia Flyers"}

      Scores.stub :new, scores do
        AutoPickTime.call(horses, picked_horses, params).must_equal({"horse_team"=>["Claude Giroux"], "other_team"=>["Kris Letang"]})
      end
    end

    it "Player 1: Second pick should be highest points player" do

      horses = {"horse_team" => [], "other_team" => ["Sidney Crosby"] }
      picked_horses = [
                        "Claude Giroux",
                        "Sidney Crosby",
                        "Kris Letang",
                     ]
  
      scores = Minitest::Mock.new

  
      scores.expect :season_goals, @season_goals 
      params = {:game_team => "Philadelphia Flyers"}

      Scores.stub :new, scores do
        AutoPickTime.call(horses, picked_horses, params).must_equal({"horse_team"=>["Wayne Simmonds"], "other_team"=>["Sidney Crosby"]})
      end
    end


    it "Player 1: Third pick should be highest points player" do

      horses = {"horse_team" => ["Wayne Simmonds"], "other_team" => ["Sidney Crosby"] }
      picked_horses = [
                        "Claude Giroux",
                        "Sidney Crosby",
                        "Kris Letang",
                        "Wayne Simmonds",
                     ]
  
      scores = Minitest::Mock.new

  
      scores.expect :season_goals, @season_goals 
      params = {:game_team => "Philadelphia Flyers"}

      Scores.stub :new, scores do
        AutoPickTime.call(horses, picked_horses, params).must_equal({"horse_team"=>["Wayne Simmonds", "Brayden Schenn"], "other_team"=>["Sidney Crosby"]})
      end
    end

    it "Player 2: Third pick should be highest points player" do

      horses = {"horse_team" => ["Claude Giroux"], "other_team" => ["Kris Letang"] }
      picked_horses = [
                        "Claude Giroux",
                        "Sidney Crosby",
                        "Kris Letang",
                        "Wayne Simmonds",
                        "Brayden Schenn",
                     ]
  
      scores = Minitest::Mock.new

  
      scores.expect :season_goals, @season_goals 
      params = {:game_team => "Philadelphia Flyers"}

      Scores.stub :new, scores do
        AutoPickTime.call(horses, picked_horses, params).must_equal({"horse_team"=>["Claude Giroux"], "other_team"=>["Kris Letang", "Phil Kessel"]})
      end
    end

    it "Player 2: Fourth pick should be highest points player" do

      horses = {"horse_team" => ["Claude Giroux"], "other_team" => ["Kris Letang","Phil Kessel"] }
      picked_horses = [
                        "Claude Giroux",
                        "Sidney Crosby",
                        "Kris Letang",
                        "Wayne Simmonds",
                        "Brayden Schenn",
                        "Phil Kessel",
                     ]
  
      scores = Minitest::Mock.new

  
      scores.expect :season_goals, @season_goals 
      params = {:game_team => "Philadelphia Flyers"}

      Scores.stub :new, scores do
        AutoPickTime.call(horses, picked_horses, params).must_equal({"horse_team"=>["Claude Giroux", "Matt Read"], "other_team"=>["Kris Letang", "Phil Kessel"]})
      end
    end

    it "Player 1: Fourth pick should be highest points player" do

      horses = {"horse_team" => ["Wayne Simmonds", "Brayden Schenn"], "other_team" => ["Sidney Crosby"] }
      picked_horses = [
                        "Claude Giroux",
                        "Sidney Crosby",
                        "Kris Letang",
                        "Wayne Simmonds",
                        "Brayden Schenn",
                        "Phil Kessel",
                        "Matt Read"
                     ]
  
      scores = Minitest::Mock.new

  
      scores.expect :season_goals, @season_goals 
      params = {:game_team => "Philadelphia Flyers"}

      Scores.stub :new, scores do
        AutoPickTime.call(horses, picked_horses, params).must_equal({"horse_team"=>["Wayne Simmonds", "Brayden Schenn"], "other_team"=>["Sidney Crosby", "Evgeni Malkin"]})
      end
    end

  end
end
