class BracketAdvancer
  # 1つの対戦カードの決着がついたら、そのラウンドの他の対戦カードを待たずに、
  # 勝者をすぐ次のラウンドの決まった枠へ入れる。以前は「このラウンドの全試合が
  # 終わるまで待つ」実装だったため、1試合だけ先に終わっても次のラウンドの枠が
  # ずっと空欄のままに見えてしまっていた。
  def self.on_match_complete(match)
    tournament = match.tournament
    next_round = match.round + 1
    return if next_round > tournament.round_count

    round_matches = tournament.matches.where(round: match.round).order(:position).to_a
    next_matches = tournament.matches.where(round: next_round).order(:position).to_a
    return if next_matches.empty?

    target_match, target_slot = target_slot_for(tournament, match, round_matches, next_matches)
    return unless target_match

    target_match.update!(target_slot => match.winner)
    target_match.reload
    if !target_match.completed? && target_match.player1.present? && target_match.player2.present?
      target_match.update!(status: "ready")
    end
  end

  # match の勝者が次のラウンドのどの対戦カードの、どちらの枠(player1/player2)に
  # 入るべきかを求める。決勝(最終ラウンド)は左右に分けず中央の1試合にまとめるので、
  # 準決勝は必ず左右1試合ずつのため、そのままplayer1/player2に対応する。それ以外は
  # 左右それぞれの中で、1回戦だけは round1_groups(シードの人数次第で対戦カード数が
  # 半分にならないことがある)、2回戦以降は隣り合う2試合ごとにまとめる従来通りの
  # 対応関係を使う。
  def self.target_slot_for(tournament, match, round_matches, next_matches)
    index = round_matches.index(match)

    if match.round + 1 == tournament.round_count && next_matches.size == 1
      return [ next_matches.first, index.zero? ? :player1 : :player2 ]
    end

    k = round_matches.size
    m = next_matches.size
    k_left = k / 2
    m_left = m / 2
    is_left = index < k_left

    side_round_matches = is_left ? round_matches.first(k_left) : round_matches.drop(k_left)
    side_next_matches = is_left ? next_matches.first(m_left) : next_matches.drop(m_left)
    local_index = side_round_matches.index(match)

    if match.round == 1
      groups = round1_groups(side_round_matches.size, side_next_matches.size)
      group_index = groups.index { |indices| indices.include?(local_index) }
      return [ nil, nil ] unless group_index

      slot_index = groups[group_index].index(local_index)
      [ side_next_matches[group_index], slot_index.zero? ? :player1 : :player2 ]
    else
      [ side_next_matches[local_index / 2], local_index.even? ? :player1 : :player2 ]
    end
  end

  # k個(前ラウンドの対戦カード数)を、隣り合った順番のまま m個(次のラウンドの
  # 対戦カード数)の枠へできるだけ均等に振り分ける。例えば k=7, m=4 なら
  # [0,1]→枠0, [2,3]→枠1, [4,5]→枠2, [6]→枠3。単純な余り(index % 枠数)で散らすと、
  # 盤面上で遠く離れた対戦カード同士が同じ枠に組み合わされ、対戦カードが引き伸ばされて
  # 線がどこに向かっているのか分からなくなる。k <= m のとき(シードが多い)は各枠に
  # 高々1つしか入らないので、シードが1回戦の勝者と当たれる枠の数を自然に最大化できる。
  def self.round1_groups(k, m)
    groups = Array.new(m) { [] }
    (0...k).each { |i| groups[(i * m) / k] << i }
    groups
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
  # (round1_groups で決まる、target_slot_for と同じ位置)は空けておき、それ以外の
  # 枠だけをシードで埋める。こうすることで、1回戦の対戦カード数が2回戦の対戦カード数
  # 以下(シードが多い)なら対戦カード1つにつき必ず1回戦の勝者が1人だけ入るように
  # なり、シードは可能な限り1回戦の勝者と当たる(シード同士が対戦するのは、1回戦の
  # 対戦カード数が2回戦の対戦カード数の2倍を超える、どうしても避けられない場合だけ
  # になる)。
  def self.seat_byes_on_side(matches, reserved_for_round1, byes)
    return if matches.empty? || byes.empty?

    reserved = []
    round1_groups(reserved_for_round1, matches.size).each_with_index do |indices, match_index|
      indices.each_with_index do |_, slot_index|
        reserved << [ match_index, slot_index.zero? ? :player1 : :player2 ]
      end
    end

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
