class PlayersValidator
  def initialize(players)
    @players = players
  end

  def valid?
    if has_duplicate_horses?
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

end