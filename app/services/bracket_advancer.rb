class BracketAdvancer
  def self.on_round_complete(tournament, round)
    next_round = round + 1
    return if next_round > tournament.round_count

    round_matches = tournament.matches.where(round: round)
    return unless round_matches.all?(&:completed?)

    next_matches = tournament.matches.where(round: next_round).order(:position).to_a
    return if next_matches.empty?

    waiting = next_matches.flat_map { |m| [ m.player1, m.player2 ] }.compact.uniq
    new_winners = round_matches.order(:position).map(&:winner).compact

    pool = (waiting + new_winners).uniq

    next_matches.each do |match|
      match.update!(player1: nil, player2: nil, winner: nil, status: "pending")
    end

    remaining_byes = assign_players_to_round(next_matches, pool)

    next_next = next_round + 1
    return if remaining_byes.empty? || next_next > tournament.round_count

    later_matches = tournament.matches.where(round: next_next).order(:position).to_a
    later_waiting = later_matches.flat_map { |m| [ m.player1, m.player2 ] }.compact.uniq
    later_pool = (later_waiting + remaining_byes).uniq

    later_matches.each do |match|
      match.update!(player1: nil, player2: nil, winner: nil, status: "pending")
    end

    assign_players_to_round(later_matches, later_pool)
  end

  def self.assign_players_to_round(matches, pool)
    return pool if matches.empty? || pool.empty?

    capacity = matches.size * 2

    if pool.size > capacity
      playing = pool.first(capacity)
      byes = pool.drop(capacity)
    else
      playing = pool
      byes = []
    end

    playing.each_slice(2).with_index do |(player1, player2), index|
      match = matches[index]
      next unless match

      match.update!(player1: player1, player2: player2, status: "ready")
    end

    byes
  end
end
