class PersonalRoundLabel
  def self.for_match(match, participant)
    return match.round_label unless participant

    my_matches = participant.matches.sort_by { |m| [ m.round, m.position ] }
    index = my_matches.index { |m| m.id == match.id }
    return match.round_label unless index

    label_for_index(match, index, my_matches.size)
  end

  def self.for_next_match(participant)
    match = participant.next_match
    return nil unless match

    for_match(match, participant)
  end

  def self.progress_label(participant)
    return "優勝" if participant.champion?

    if participant.eliminated?
      opponent = participant.defeated_by
      return opponent ? "敗退（#{opponent.display_name}）" : "敗退"
    end

    return "第1回戦待機" if participant.waiting_first_round?

    my_matches = participant.matches.sort_by { |m| [ m.round, m.position ] }
    won_count = my_matches.count { |m| m.completed? && m.winner_id == participant.id }

    if (next_match = participant.next_match)
      round_name = for_match(next_match, participant)
      return "#{round_name}（次の対戦）"
    end

    return "第1回戦出場前" if won_count.zero?

    last_won = my_matches.reverse.find { |m| m.completed? && m.winner_id == participant.id }
    return "—" unless last_won

    "#{for_match(last_won, participant)}突破"
  end

  def self.label_for_index(match, index, _total)
    return "決勝" if match.round == match.tournament.round_count

    "第#{index + 1}回戦"
  end
end
