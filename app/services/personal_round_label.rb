class PersonalRoundLabel
  def self.for_match(match, participant)
    return match.round_label unless participant
    return match.round_label unless participant.matches.any? { |m| m.id == match.id }

    label_for_round(match)
  end

  def self.for_next_match(participant)
    match = participant.next_match
    return nil unless match

    for_match(match, participant)
  end

  def self.progress_label(participant)
    return "優勝" if participant.champion?

    if participant.eliminated?
      losing_match = participant.losing_match
      round_label = losing_match ? for_match(losing_match, participant) : nil
      opponent = participant.defeated_by

      return "#{round_label}敗退（#{opponent.display_name}）" if round_label && opponent
      return "#{round_label}敗退" if round_label

      opponent ? "敗退（#{opponent.display_name}）" : "敗退"
    end

    if participant.waiting_first_round?
      return "#{label_for_round(participant.matches.first)}待機"
    end

    my_matches = participant.matches.sort_by { |m| [ m.round, m.position ] }
    won_count = my_matches.count { |m| m.completed? && m.winner_id == participant.id }

    if (next_match = participant.next_match)
      round_name = for_match(next_match, participant)
      opponent = participant.opponent_in(next_match)
      return "#{round_name}（#{opponent.display_name}）" if opponent

      return "#{round_name}（次の対戦）"
    end

    return "第1回戦出場前" if won_count.zero?

    last_won = my_matches.reverse.find { |m| m.completed? && m.winner_id == participant.id }
    return "—" unless last_won

    "#{for_match(last_won, participant)}突破"
  end

  # 個人視点での「第何回戦」は、本人の対戦数ではなく実際のトーナメントの
  # ラウンド番号をそのまま使う。シード(不戦勝)の人は1回戦を戦わず2回戦から
  # 参加するため、その人にとっての初戦も「第2回戦」として数える。
  def self.label_for_round(match)
    return "決勝" if match.round == match.tournament.round_count

    "第#{match.round}回戦"
  end
end
