class CompactBracket
  def self.compact_odd?(participant_count)
    participant_count.odd? && participant_count >= 3
  end

  def self.round_match_counts(participant_count)
    return [] if participant_count < 2
    return [ 1 ] if participant_count == 2
    return compact_odd_round_counts(participant_count) if compact_odd?(participant_count)

    BracketGenerator.standard_round_match_counts(participant_count)
  end

  def self.round_count(participant_count)
    round_match_counts(participant_count).size
  end

  def self.waiting_participant?(tournament, participant)
    return false unless compact_odd?(tournament.participants.count)

    participant.id == waiting_participant(tournament)&.id
  end

  def self.waiting_participant(tournament)
    tournament.participants.order(:seed).last
  end

  def self.on_round_complete(tournament, round)
    # この試合が決勝そのものなら、これ以上組み上げる先のラウンドは無い。
    # (奇数人数の変則ブラケットでは決勝の位置がラウンド2や3になることがあるため、
    #  ここでガードしないと populate_final! が確定済みの決勝を再度 "ready" に戻してしまう)
    return if round >= tournament.round_count

    return BracketAdvancer.on_round_complete(tournament, round) unless compact_odd?(tournament.participants.count)

    round_matches = tournament.matches.where(round: round)
    return unless round_matches.all?(&:completed?)

    n = tournament.participants.count
    r1_count = (n - 1) / 2
    left_r1 = (r1_count + 1) / 2
    right_r1 = r1_count - left_r1
    left_r2 = left_r1 >= 2 ? 1 : 0
    r1_winners = tournament.matches.where(round: 1).order(:position).map(&:winner)
    waiter = waiting_participant(tournament)

    case round
    when 1
      next_matches = tournament.matches.where(round: 2).order(:position).to_a
      assign_ready(next_matches[0], r1_winners[0], r1_winners[1]) if left_r2.positive?
      assign_ready(next_matches[left_r2], r1_winners[r1_count - 1], waiter)
    when 2
      if right_r1 >= 2
        play_in_winner = tournament.matches.find_by!(round: 2, position: left_r2).winner
        assign_ready(
          tournament.matches.find_by!(round: 3, position: 0),
          r1_winners[left_r1],
          play_in_winner
        )
      else
        populate_final!(tournament, r1_winners, left_r2)
      end
    when 3
      populate_final!(tournament, r1_winners, left_r2)
    end
  end

  def self.populate_final!(tournament, r1_winners, left_r2)
    final_match = tournament.matches.where(round: tournament.round_count).order(:position).first
    return unless final_match

    n = tournament.participants.count
    r1_count = (n - 1) / 2
    left_r1 = (r1_count + 1) / 2
    right_r1 = r1_count - left_r1

    left_finalist = left_r2.positive? ? tournament.matches.find_by!(round: 2, position: 0).winner : r1_winners[0]
    right_finalist = if right_r1 >= 2
      tournament.matches.find_by!(round: 3, position: 0).winner
    else
      tournament.matches.find_by!(round: 2, position: left_r2).winner
    end

    assign_ready(final_match, left_finalist, right_finalist)
  end

  def self.assign_ready(match, player1, player2)
    return unless match && player1 && player2

    match.update!(player1: player1, player2: player2, status: "ready")
  end

  def self.tree_definition(participant_count)
    return nil unless compact_odd?(participant_count)

    r1_count = (participant_count - 1) / 2
    left_r1 = (r1_count + 1) / 2
    right_r1 = r1_count - left_r1
    left_r2 = left_r1 >= 2 ? 1 : 0
    rounds = round_match_counts(participant_count).size

    r1_pairs = (0...r1_count).map { |pos| [ pos * 2, pos * 2 + 1 ] }
    nodes = []

    r1_pairs.each_with_index do |slots, pos|
      nodes << { id: "r1_#{pos}", round: 1, position: pos, slots: slots, level: 1 }
    end

    play_in_pos = left_r2
    nodes << { id: "r2_#{play_in_pos}", round: 2, position: play_in_pos, slots: [ r1_pairs.last&.last, participant_count - 1 ].compact, level: 2, play_in: true } if r1_count.positive?

    if left_r2.positive?
      nodes << { id: "r2_0", round: 2, position: 0, child_positions: [ 0, 1 ], level: 2, left_semi: true }
    end

    if right_r1 >= 2
      nodes << { id: "r3_0", round: 3, position: 0, child_positions: [ left_r1, play_in_pos ], level: 3, right_semi: true }
      nodes << { id: "r#{rounds}_0", round: rounds, position: 0, child_positions: [ 0, 0 ], child_rounds: [ 2, 3 ], level: rounds, final: true, left_child: 0, right_child: 0, right_child_round: 3 }
    else
      nodes << { id: "r#{rounds}_0", round: rounds, position: 0, level: rounds, final: true, left_from_round: left_r2.positive? ? 2 : 1, right_from_round: 2, right_position: left_r2 }
    end

    {
      participant_count: participant_count,
      rounds: rounds,
      r1_count: r1_count,
      left_r1: left_r1,
      right_r1: right_r1,
      left_r2: left_r2,
      waiter_slot: participant_count - 1,
      r1_pairs: r1_pairs,
      nodes: nodes
    }
  end

  def self.compact_odd_round_counts(n)
    r1 = (n - 1) / 2
    left_r1 = (r1 + 1) / 2
    right_r1 = r1 - left_r1
    left_r2 = left_r1 >= 2 ? 1 : 0

    counts = [ r1, left_r2 + 1 ]
    counts << 1 if right_r1 >= 2
    counts << 1 if n > 3 && (right_r1 >= 2 || left_r2.positive? || (left_r2.zero? && right_r1 >= 1))
    counts
  end
end
