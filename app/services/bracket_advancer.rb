class BracketAdvancer
  def self.on_round_complete(tournament, round)
    next_round = round + 1
    return if next_round > tournament.round_count

    round_matches = tournament.matches.where(round: round)
    return unless round_matches.all?(&:completed?)

    next_matches = tournament.matches.where(round: next_round).order(:position).to_a
    return if next_matches.empty?

    round_matches_ordered = round_matches.order(:position).to_a
    new_winners = round_matches_ordered.map(&:winner).compact

    if next_round == tournament.round_count
      # 決勝(最終ラウンド)は左右に分けず中央の1試合にまとめるので、両側の勝者を
      # まとめてそのまま1つの対戦カードに入れる。
      seat_arrivals(next_matches, new_winners)
    else
      k_left = round_matches_ordered.size / 2
      m_left = next_matches.size / 2

      seat_arrivals(next_matches.first(m_left), new_winners.first(k_left))
      seat_arrivals(next_matches.drop(m_left), new_winners.drop(k_left))
    end
  end

  # 前ラウンドの勝者たちを、対戦カード0番目の1人目の枠→2人目の枠→1番目の1人目の枠…
  # という順番で入れていく。この対応関係は、生成時にシード(不戦勝)を配置した位置
  # (seat_byes_on_side)と必ず一致していなければならない。ずれると盤面の接続線
  # (bracket_controller.js の connectSide、同じ 0番目→1人目/2人目の順で対戦カードを
  # 結んでいる)が、シードの枠を指してしまったり、逆に勝者の枠を見失ったりする。
  def self.seat_arrivals(matches, arrivals)
    return if matches.empty? || arrivals.empty?

    arrivals.each_with_index do |winner, index|
      match = matches[index / 2]
      next unless match

      slot = index.even? ? :player1 : :player2
      match.update!(slot => winner)
    end

    matches.each do |match|
      match.reload
      next if match.completed?

      match.update!(status: "ready") if match.player1.present? && match.player2.present?
    end
  end

  # 1回戦の対戦カードと同じ左右比率(BracketHelper#bracket_left_right_center の
  # 「前半/後半」の分け方)で、シード(不戦勝)を2回戦の対戦カードへ割り振る。
  def self.assign_byes_evenly(round1_matches, round2_matches, byes)
    return if round2_matches.empty? || byes.empty?

    k = round1_matches.size
    m = round2_matches.size
    k_left = k / 2
    m_left = m / 2

    byes_for_left = [ (2 * m_left) - k_left, 0 ].max
    byes_for_left = [ byes_for_left, byes.size ].min

    seat_byes_on_side(round2_matches.first(m_left), k_left, byes.first(byes_for_left))
    seat_byes_on_side(round2_matches.drop(m_left), k - k_left, byes.drop(byes_for_left))
  end

  # 片側ぶんの対戦カードへシードを割り振る。1回戦の勝者が入る予定の枠
  # (seat_arrivals と同じ、0番目の対戦カードの1人目→2人目→1番目の対戦カードの1人目…
  # という順)は空けておき、それ以外の枠だけをシードで埋める。こうしないと、
  # まだ1回戦の結果が出ていないのに、盤面の接続線が指す枠に既にシードが
  # 座っているように見えてしまう。
  def self.seat_byes_on_side(matches, reserved_for_round1, byes)
    return if matches.empty? || byes.empty?

    reserved = Array.new(reserved_for_round1) { |i| [ i / 2, i.even? ? :player1 : :player2 ] }

    available_slots = []
    matches.each_with_index do |match, index|
      available_slots << [ match, :player1 ] unless reserved.include?([ index, :player1 ])
      available_slots << [ match, :player2 ] unless reserved.include?([ index, :player2 ])
    end

    byes.first(available_slots.size).each_with_index do |bye, i|
      match, slot = available_slots[i]
      match.update!(slot => bye)
    end

    matches.each do |match|
      match.reload
      match.update!(status: "ready") if match.player1.present? && match.player2.present?
    end
  end
end
