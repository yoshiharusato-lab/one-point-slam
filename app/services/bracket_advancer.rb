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
        # 同じ「対戦カードへ均等に割り振る」順番で勝者を入れる(下記参照)。
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

  # 1回戦の勝者たちを、対戦カードへ「1人ずつ均等に」割り振ってから入れる
  # (seat_byes_on_side が空けておいた予約枠と必ず同じ位置)。1回戦はシードの人数
  # 次第で対戦カード数が2倍にならないことがあるため(例: 12人なら1回戦2試合・
  # 2回戦2試合)、seat_arrivals のように隣り合う2試合をまとめてしまうと、片方の
  # 対戦カードに勝者が2人とも入って対戦カードに、逆側にシード同士が入ってしまい、
  # せっかくシードがいるのに1回戦の勝者と当たれない対戦カードができてしまう。
  def self.seat_round1_winners_on_side(matches, winners)
    return if matches.empty? || winners.empty?

    m = matches.size
    winners.each_with_index do |winner, i|
      match = matches[i % m]
      slot = (i / m).zero? ? :player1 : :player2
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
  # (seat_round1_winners_on_side と同じ、対戦カードへ1人ずつ均等に割り振る順番)は
  # 空けておき、それ以外の枠だけをシードで埋める。均等に割り振ることで、1回戦の
  # 対戦カード数が2回戦の対戦カード数以下(シードが多い)なら、対戦カード1つに
  # つき必ず1回戦の勝者が1人だけ入るようになり、シードは可能な限り1回戦の勝者と
  # 当たる(シード同士が対戦するのは、1回戦の対戦カード数が2回戦の対戦カード数の
  # 2倍を超える、どうしても避けられない場合だけになる)。
  def self.seat_byes_on_side(matches, reserved_for_round1, byes)
    return if matches.empty? || byes.empty?

    m = matches.size
    reserved = Array.new(reserved_for_round1) { |i| [ i % m, (i / m).zero? ? :player1 : :player2 ] }

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
