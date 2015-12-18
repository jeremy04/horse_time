class PickOrder
  def initialize(draft_order, rounds=4)
    @draft_order = draft_order
    @rounds = rounds
  end

  def generate_pick_order
    pick_order = {}
    teams = @draft_order.size
    total = teams * @rounds
    @draft_order.each_with_index do |value, index|
      total.times do |i|
        if (teams + 0.5 - ((i) % (2*teams)+1)).abs == teams + 0.5-(index + 1)
          pick_order[i+1] = value
        end
      end
    end
    pick_order
  end

end