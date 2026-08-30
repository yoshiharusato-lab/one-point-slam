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

      if round == 1
        # 1回戦だけはシード(不戦勝)が絡むため、生成時の seat_byes_on_side と
        # 同じ「隣り合った対戦カードごとにまとめる」順番で勝者を入れる(下記参照)。
        seat_round1_winners_on_side(next_matches.first(m_left), new_winners.first(k_left))
        seat_round1_winners_on_side(next_matches.drop(m_left), new_winners.drop(k_left))
      else
        seat_arrivals(next_matches.first(m_left), new_winners.first(k_left))
        seat_arrivals(next_matches.drop(m_left), new_winners.drop(k_left))
      end
    end
  end

  # 前ラウンドの勝者たちを、対戦カード0番目の1人目の枠→2人目の枠→1番目の1人目の枠…
  # という順番で入れていく(1回戦以外は、参加者数の関係で対戦カード数がちょうど
  # 半分になるため、この順番が常に「隣り合う2つの対戦カードの勝者が同じ枠に入る」
  # という従来通りの組み方と一致する)。盤面の接続線(bracket_controller.js の
  # connectSide)も同じ順番を前提にしている。
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

  # k個(1回戦の対戦カード数)を、隣り合った順番のまま m個(2回戦の対戦カード数)の
  # 枠へできるだけ均等に振り分ける。例えば k=7, m=4 なら [0,1]→枠0, [2,3]→枠1,
  # [4,5]→枠2, [6]→枠3。単純な余り(index % 枠数)で散らすと、盤面上で遠く離れた
  # 対戦カード同士が同じ枠に組み合わされてしまい、対戦カードが引き伸ばされて
  # 線がどこに向かっているのか分からなくなる(実際に30人規模で確認された)。
  # k <= m のとき(シードが多い)は各枠に高々1つしか入らないので、シードが
  # 1回戦の勝者と当たれる枠の数を自然に最大化できる。
  def self.round1_groups(k, m)
    groups = Array.new(m) { [] }
    (0...k).each { |i| groups[(i * m) / k] << i }
    groups
  end

  # 1回戦の勝者たちを、対戦カードへ round1_groups と同じ組み方で入れる
  # (seat_byes_on_side が空けておいた予約枠と必ず同じ位置)。
  def self.seat_round1_winners_on_side(matches, winners)
    return if matches.empty? || winners.empty?

    round1_groups(winners.size, matches.size).each_with_index do |indices, match_index|
      match = matches[match_index]
      indices.each_with_index do |winner_index, slot_index|
        slot = slot_index.zero? ? :player1 : :player2
        match.update!(slot => winners[winner_index])
      end
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
  # (round1_groups で決まる、seat_round1_winners_on_side と同じ位置)は空けておき、
  # それ以外の枠だけをシードで埋める。こうすることで、1回戦の対戦カード数が
  # 2回戦の対戦カード数以下(シードが多い)なら対戦カード1つにつき必ず1回戦の
  # 勝者が1人だけ入るようになり、シードは可能な限り1回戦の勝者と当たる
  # (シード同士が対戦するのは、1回戦の対戦カード数が2回戦の対戦カード数の
  # 2倍を超える、どうしても避けられない場合だけになる)。
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
