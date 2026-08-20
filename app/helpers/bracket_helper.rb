module BracketHelper
  MATCH_UNIT = 56

  def bracket_slot_count(tournament)
    tournament.participants.count
  end

  def bracket_matches_by_round(tournament)
    tournament.matches
      .includes(:player1, :player2, :winner)
      .ordered
      .group_by(&:round)
  end

  def bracket_match_margin_top(round, position)
    unit = MATCH_UNIT
    (((2**(round - 1) - 1) * unit / 2.0) + (position * (2**(round - 1)) * unit)).round
  end

  def bracket_pair_span(round)
    (2**(round - 1) * MATCH_UNIT).round
  end

  def bracket_match_block_height
    48
  end

  def bracket_vertical_connector_height(round, _position)
    bracket_pair_span(round) + bracket_match_block_height
  end

  def bracket_show_connector?(position, match_count)
    position.even? && position + 1 < match_count
  end

  def bracket_slot_label(participant)
    participant&.display_name || "—"
  end

  def bracket_slot_status(participant, tournament)
    return :empty unless participant

    return :champion if participant.champion?
    return :eliminated if participant.eliminated?
    return :waiting if participant.waiting_first_round?
    return :playing if participant.next_match&.playable?
    return :advanced if participant.advanced?

    :pending
  end

  def bracket_slot_status_badge(participant, tournament)
    case bracket_slot_status(participant, tournament)
    when :champion then "優勝"
    when :eliminated then "敗"
    when :waiting then "待機"
    when :playing then "対戦中"
    when :advanced then "勝ち"
    else nil
    end
  end

  def bracket_slot_classes(participant, tournament, viewing_user)
    classes = [ "tree-bracket__slot" ]
    return classes.join(" ") unless participant

    status = bracket_slot_status(participant, tournament)
    classes << "tree-bracket__slot--#{status}"
    classes << "tree-bracket__slot--mine" if viewing_user && participant.user_id == viewing_user.id
    classes.join(" ")
  end

  def bracket_name_classes(participant, tournament, viewing_user, clickable: false)
    classes = [ "tree-bracket__name" ]
    classes << "tree-bracket__name--clickable" if clickable

    status = bracket_slot_status(participant, tournament)
    classes << "tree-bracket__name--#{status}"
    classes << "tree-bracket__name--mine" if viewing_user && participant&.user_id == viewing_user.id
    classes.join(" ")
  end

  def bracket_progress_label(participant, tree)
    PersonalRoundLabel.progress_label(participant)
  end

  def bracket_player_classes(participant, match, viewing_user)
    classes = [ "bracket-player" ]
    classes << "bracket-player--empty" if participant.nil?
    classes << "bracket-player--winner" if participant && match.winner_id == participant.id
    classes << "bracket-player--mine" if viewing_user && participant&.user_id == viewing_user.id
    classes << "bracket-player--loser" if participant && match.completed? && match.winner_id != participant.id
    classes.join(" ")
  end

  def bracket_match_classes(match, viewing_user)
    classes = [ "bracket-match" ]
    classes << "bracket-match--playable" if match.playable?
    classes << "bracket-match--completed" if match.completed?
    classes << "bracket-match--mine" if viewing_user && match.involves?(viewing_user) && match.playable?
    classes << "bracket-match--bye" if match.status == "bye"
    classes << "bracket-match--last-round" if match.round == match.tournament.round_count
    classes.join(" ")
  end

  def bracket_can_vote?(match, participant, viewing_user)
    match&.playable? && participant.present? && viewing_user && match.involves?(viewing_user)
  end

  def bracket_round_title(round, total_rounds)
    remaining = total_rounds - round + 1
    case remaining
    when 1 then "決勝"
    when 2 then "準決勝"
    when 3 then "準々決勝"
    else "第#{round}ラウンド"
    end
  end

  def tournament_participant(tournament, user)
    return nil unless user

    tournament.participants.find_by(user: user)
  end

  def tournament_default_view(tournament, user)
    if user&.admin? || tournament_participant(tournament, user).nil?
      "full"
    else
      "mine"
    end
  end
end
