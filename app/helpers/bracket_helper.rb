module BracketHelper
  def bracket_can_vote?(match, participant, viewing_user)
    match&.playable? && participant.present? && viewing_user && match.involves?(viewing_user)
  end

  def bracket_round_title(round, total_rounds)
    remaining = total_rounds - round + 1
    case remaining
    when 1 then "決勝"
    when 2 then "準決勝"
    when 3 then "準々決勝"
    else "#{round}回戦"
    end
  end

  def tournament_participant(tournament, user)
    return nil unless user

    tournament.participants.find_by(user: user)
  end

  # トーナメント表を左半分・中央(決勝)・右半分に分ける。
  # 各ラウンドの対戦カードを前半/後半で左右に振り分け、決勝だけ中央に置く
  # 左右対称レイアウト(旧tweet_appのブラケット表と同じ組み方)。
  def bracket_left_right_center(tournament)
    total_rounds = tournament.round_count
    empty_final = { label: bracket_round_title(1, 1), matches: [] }
    return { left: [], right: [], final: empty_final } if total_rounds.zero?

    matches_by_round = tournament.matches.includes(:player1, :player2, :winner).ordered.group_by(&:round)

    rounds = (1..total_rounds).map do |round|
      { label: bracket_round_title(round, total_rounds), matches: (matches_by_round[round] || []).sort_by(&:position) }
    end

    left = []
    right = []
    rounds[0...-1].each do |round_data|
      half = round_data[:matches].length / 2
      left << { label: round_data[:label], matches: round_data[:matches].first(half) }
      right << { label: round_data[:label], matches: round_data[:matches].drop(half) }
    end

    { left: left, right: right, final: rounds.last }
  end

  def bracket_match_state_class(match)
    return "match-decided" if match.completed?
    return "match-ready" if match.playable?

    "match-pending"
  end

  def bracket_player_state_class(participant, match)
    return "" unless participant && match.completed?

    match.winner_id == participant.id ? "is-winner" : "is-loser"
  end
end
