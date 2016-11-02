require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/all'
require 'pp'

class PlayerStats
  def initialize(stats)
    @stats = stats.with_indifferent_access
  end

  def points
    if valid?(:points)
      @stats[:stats].first[:splits].first[:stat][:points]
    else
      0
    end
  end

  def goals
    if valid?(:goals)
      @stats[:stats].first[:splits].first[:stat][:goals]
    else
      0
    end
  end

  def assists
    if valid?(:assists)
      @stats[:stats].first[:splits].first[:stat][:assists]
    else
      0
    end
  end

  private

  def valid?(key)
    @stats.try(:[], :stats).try(:first).try(:[], :splits).try(:first).try(:[], :stat).try(:[], key)
  end

end