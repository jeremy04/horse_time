require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/all'
require 'pp'

class PlayerStats
  def initialize(stats)
    @stats = stats.with_indifferent_access
  end

  def points
    if valid?
      @stats[:stats].first[:splits].first[:stat][:points]
    else
      0
    end
  end

  private

  def valid?
    @stats.try(:[], :stats).try(:first).try(:[], :splits).try(:first).try(:[], :stat).try(:[], :points)
  end

end