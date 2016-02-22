require_relative '../lib/player_stats'
require 'minitest/autorun'

describe PlayerStats do
  before do
    stats = 
      { stats: [{ splits: [{ stat: { points: 19 } }] }] }

    @player_stats = PlayerStats.new(stats)
  end

  describe "points" do
    it "returns true when points is available" do
      @player_stats.points.must_equal 19
    end

    it "returns 0 points when no stats" do
      stats = { woo: [{ splits: [{ stat: { points: 19 } }] }] }
      @player_stats = PlayerStats.new(stats)
      @player_stats.points.must_equal 0
    end

    it "returns 0 points when no splits" do
      stats = { stats: [] }
      @player_stats = PlayerStats.new(stats)
      @player_stats.points.must_equal 0
    end

    it "returns 0 points when no stats" do
      stats = { stats: [{ splits: [] }] }
      @player_stats = PlayerStats.new(stats)
      @player_stats.points.must_equal 0
    end

    it "returns 0 points when no points" do
      stats = { stats: [{ splits: [{ stat: {} }] }] }
      @player_stats = PlayerStats.new(stats)
      @player_stats.points.must_equal 0
    end

  end

end