require 'active_support/all'

class PlayersValidator
  def initialize(players, horses_per)
    @players = players
    @horses_per = horses_per
  end

  def valid?
    if has_duplicate_horses? || max_picks
      false
    else
      true
    end
  end

  private

  def has_duplicate_horses?
    horses = @players.map { |p| p["horses"] }.flatten.map { |h| h.values }.flatten
    !(horses.uniq.length == horses.length)
  end

  def max_picks
    (@players.map { |p| p["horses"] }.select { |h| h["horse_team"].size > @horses_per }.present? || 
    @players.map { |p| p["horses"] }.select { |h| h["other_team"].size > @horses_per }.present?)
  end

end