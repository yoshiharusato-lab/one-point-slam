class BracketTreeSvg
  SLOT_W = 36
  MARGIN_X = 16
  NAME_Y_OFFSET = 18
  V_STEP = 50
  STUB = 12

  Segment = Struct.new(:id, :d, :round, :position, :slot, :kind, keyword_init: true)

  def initialize(tournament)
    @tournament = tournament
    participant_count = tournament.participants.count
    @slots = participant_count.positive? ? participant_count : 2
    @round_match_counts = BracketGenerator.round_match_counts(participant_count)
    @rounds = @round_match_counts.size
    @matches_by_round = tournament.matches.includes(:player1, :player2, :winner).ordered.group_by(&:round)
  end

  def width
    @slots * SLOT_W + MARGIN_X * 2
  end

  def height
    NAME_Y_OFFSET + @rounds * V_STEP + 44
  end

  def slot_width
    SLOT_W
  end

  def name_y
    height - NAME_Y_OFFSET
  end

  def structure_segments
    @structure_segments ||= build_structure_standard_segments
  end

  def winner_segments
    @winner_segments ||= build_winner_standard_segments
  end

  def entry_slots
    participants = @tournament.participants.includes(:user).order(:seed, :id).to_a
    r1_matches = (@matches_by_round[1] || []).sort_by(&:position)

    participants.map.with_index do |participant, index|
      match = r1_matches.find { |m| m.player1_id == participant.id || m.player2_id == participant.id }
      {
        index: index,
        participant: participant,
        match: match,
        waiting_first_round: participant.waiting_first_round?
      }
    end
  end

  def farthest_round_label(participant)
    PersonalRoundLabel.progress_label(participant)
  end

  private

  def still_active?(participant)
    return false unless participant

    !participant.eliminated? || participant.champion?
  end

  def build_structure_standard_segments
    list = []
    @match_centers = build_match_centers
    y1 = round_y(1)

    entry_slots.each do |entry|
      next unless entry[:match]

      x = slot_center_x(entry[:index])
      xm = @match_centers.dig(1, entry[:match].position)
      next unless xm

      list << seg("struct_leaf_#{entry[:index]}", "M #{x} #{name_y} V #{y1} H #{xm}", :structure, entry[:index])
    end

    @round_match_counts[0].times do |position|
      xm = @match_centers.dig(1, position)
      next unless xm

      list << seg("struct_r1_up_#{position}", "M #{xm} #{y1} V #{round_y(2)}", :structure)
    end

    if @rounds == 1
      xm = @match_centers.dig(1, 0)
      if xm
        list << seg("struct_final", "M #{xm} #{round_y(1) - STUB} V #{champion_y - STUB}", :structure)
        list << seg("struct_champion", "M #{xm} #{champion_y - STUB} V #{champion_y - 36}", :structure)
      end
      return list
    end

    (2..@rounds).each do |round|
      match_count = @round_match_counts[round - 1]

      match_count.times do |position|
        left_child = @match_centers.dig(round - 1, position * 2)
        right_child = @match_centers.dig(round - 1, position * 2 + 1)
        xm = @match_centers.dig(round, position)
        next unless xm

        y_child = round_y(round)
        y_next = round < @rounds ? round_y(round + 1) : champion_y

        if left_child
          list << seg("struct_join_#{round}_#{position}_l", "M #{left_child} #{y_child} V #{y_child - STUB} H #{xm}", :structure)
        end

        if right_child
          list << seg("struct_join_#{round}_#{position}_r", "M #{right_child} #{y_child} V #{y_child - STUB} H #{xm}", :structure)
        end

        if round == @rounds
          list << seg("struct_final_#{position}", "M #{xm} #{y_child - STUB} V #{y_next - STUB}", :structure)
          list << seg("struct_champion", "M #{xm} #{y_next - STUB} V #{y_next - 36}", :structure)
        else
          list << seg("struct_r#{round}_#{position}", "M #{xm} #{y_child - STUB} V #{y_next - STUB}", :structure)
        end
      end
    end

    list
  end

  def build_winner_standard_segments
    list = []
    @match_centers = build_match_centers
    y1 = round_y(1)

    (@matches_by_round[1] || []).each do |match|
      next unless match.player1 && match.player2

      if match.completed? && match.winner
        next unless still_active?(match.winner)

        slot = slot_index_for(match.winner_id)
        x = slot_center_x(slot)
        list << seg("win_leaf_#{slot}", "M #{x} #{name_y} V #{y1}", :win, slot)
        add_standard_winner_path(list, match, slot)
      else
        slot_indices_for(match).each do |slot|
          x = slot_center_x(slot)
          list << seg("win_leaf_#{slot}", "M #{x} #{name_y} V #{y1}", :win, slot)
        end
      end
    end

    (2..@rounds).each do |round|
      (@matches_by_round[round] || []).each do |match|
        next unless match.completed? && match.winner
        next unless still_active?(match.winner)

        add_standard_winner_path(list, match, slot_index_for(match.winner_id))
      end
    end

    if @tournament.champion
      xm = @match_centers.dig(@rounds, 0)
      list << seg("win_champion", "M #{xm} #{champion_y - STUB} V #{champion_y - 36}", :win) if xm
    end

    list
  end

  def add_standard_winner_path(list, match, winner_slot)
    return unless winner_slot

    round = match.round
    xm = @match_centers.dig(round, match.position)
    return unless xm

    x = slot_center_x(winner_slot)
    y_next = round < @rounds ? round_y(round + 1) : champion_y

    if round == 1
      list << seg("win_up_#{winner_slot}_1", "M #{x} #{round_y(1)} V #{round_y(2)}", :win, winner_slot)
    end

    if round < @rounds
      next_xm = @match_centers.dig(round + 1, match.position / 2)
      if next_xm
        list << seg("win_join_#{round}_#{match.position}", "M #{x} #{round_y(round + 1)} V #{round_y(round + 1) - STUB} H #{next_xm}", :win, winner_slot)
        list << seg("win_r#{round}_#{match.position}", "M #{next_xm} #{round_y(round + 1) - STUB} V #{y_next - STUB}", :win, winner_slot)
      end
    else
      list << seg("win_final_#{match.position}", "M #{xm} #{round_y(round) - STUB} V #{y_next - STUB}", :win, winner_slot)
    end
  end

  def seg(id, d, kind, slot = nil)
    Segment.new(id: id, d: d, round: 0, position: 0, slot: slot, kind: kind)
  end

  def slot_index_for(participant_id)
    entry_slots.find_index { |e| e[:participant]&.id == participant_id }
  end

  def slot_indices_for(match)
    [ slot_index_for(match.player1_id), slot_index_for(match.player2_id) ].compact
  end

  def build_match_centers
    centers = {}
    r1_matches = (@matches_by_round[1] || []).sort_by(&:position)

    centers[1] = r1_matches.map do |match|
      slots = slot_indices_for(match)
      if slots.size == 2
        (slot_center_x(slots[0]) + slot_center_x(slots[1])) / 2.0
      elsif slots.size == 1
        slot_center_x(slots[0])
      end
    end

    (2..@rounds).each do |round|
      match_count = @round_match_counts[round - 1]
      prev_centers = centers[round - 1] || []
      round_centers = []

      match_count.times do |position|
        left = prev_centers[position * 2]
        right = prev_centers[position * 2 + 1]
        children = [ left, right ].compact

        round_centers[position] = if children.size == 2
          (children[0] + children[1]) / 2.0
        elsif children.size == 1
          children[0]
        end
      end

      centers[round] = round_centers
    end

    centers
  end

  def slot_center_x(index)
    MARGIN_X + index * SLOT_W + SLOT_W / 2.0
  end

  def round_y(round)
    name_y - STUB - (round - 1) * V_STEP
  end

  def champion_y
    name_y - STUB - @rounds * V_STEP
  end
end
