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

    # 決勝(最終ラウンド)は左右に分けず中央の1試合にまとめるので、そこへの遷移だけは
    # 左右split をせず、両側の勝者をまとめて1つの対戦カードに入れる。
    remaining_byes = if next_round == tournament.round_count
      populate_round(next_matches, new_winners)
    else
      populate_round_by_side(round_matches_ordered, next_matches, new_winners)
    end

    next_next = next_round + 1
    return if remaining_byes.empty? || next_next > tournament.round_count

    later_matches = tournament.matches.where(round: next_next).order(:position).to_a
    populate_round(later_matches, remaining_byes)
  end

  # 前のラウンドと同じ左右比率(assign_byes_evenly と同じ考え方)で、片側ずつ独立に
  # populate_round を行う。全体を1つのプールとして順番に詰めてしまうと、ある枠が
  # まだ空(=前のラウンドの勝者を2人とも待っている)なせいで、後ろに並ぶ逆サイドの
  # 枠が先に勝者を受け取ってしまい、勝者が反対側に紛れ込むことがあるため。
  def self.populate_round_by_side(round_matches, next_matches, arrivals)
    return arrivals if next_matches.empty? || arrivals.empty?

    k_left = round_matches.size / 2
    m_left = next_matches.size / 2

    left_remaining = populate_round(next_matches.first(m_left), arrivals.first(k_left))
    right_remaining = populate_round(next_matches.drop(m_left), arrivals.drop(k_left))

    left_remaining + right_remaining
  end

  # 新しく決まった参加者(前ラウンドの勝者など)を対戦カードに割り振る。
  # 既に片方の枠にシード(不戦勝)が入って相手を待っているカードを優先して埋め、
  # まっさらな枠だけを新規にペアリングする。こうすることで、シードで待っていた
  # 枠に無関係の2人が組まれ直したり、逆に前ラウンドの勝者同士がぶつかったりしない。
  def self.populate_round(matches, arrivals)
    return arrivals if matches.empty? || arrivals.empty?

    pool = arrivals.dup
    empty_matches = []

    matches.each do |match|
      seated = [ match.player1, match.player2 ].compact
      next if seated.size == 2

      if seated.size == 1
        next if pool.empty?

        opponent = pool.shift
        slot = match.player1.present? ? :player2 : :player1
        match.update!(slot => opponent, status: "ready")
      else
        empty_matches << match
      end
    end

    assign_players_to_round(empty_matches, pool)
  end

  # 1回戦の対戦カードと同じ左右比率(BracketHelper#bracket_left_right_center の
  # 「前半/後半」の分け方)で、シード(不戦勝)を2回戦の対戦カードへ割り振る。
  #
  # 単純に対戦カード全体へ順番に(0番目, 1番目, ...と)割り振ってしまうと、1回戦の
  # 対戦カード数と2回戦の対戦カード数が一致しない場合(例: 1回戦2試合→2回戦4枠)に、
  # 表示上「左側」になる2回戦の枠が両方ともシード同士の対戦で埋まり、逆に1回戦の
  # 左側の勝者は「右側」の2回戦枠へ回されてしまう、という表示と実際の勝ち上がりが
  # 食い違うバグが起きる。1回戦・2回戦それぞれを同じ前半/後半の比率で左右に分け、
  # 片側ずつ独立にシードを割り振ることで、1回戦の左側の勝者は必ず2回戦の左側に、
  # 右側の勝者は必ず右側に入るようにする。
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

  # 片側ぶんの2回戦カードへシードを割り振る。まず全カードに1人ずつ配置して
  # 1回戦の勝者を待つ状態にし、余ったシードだけ(1回戦の対戦カード数ぶんの枠を
  # 除いて)2人目として入れる。
  def self.seat_byes_on_side(matches, reserved_for_round1, byes)
    return if matches.empty? || byes.empty?

    first_pass = byes.first(matches.size)
    first_pass.each_with_index do |bye, index|
      matches[index].update!(player1: bye, status: "pending")
    end

    fillable = [ matches.size - reserved_for_round1, 0 ].max
    second_pass = byes.drop(matches.size).first(fillable)
    second_pass.each_with_index do |bye, index|
      matches[index].update!(player2: bye, status: "ready")
    end
  end

  def self.assign_players_to_round(matches, pool)
    return pool if matches.empty? || pool.empty?

    capacity = matches.size * 2

    if pool.size > capacity
      playing = pool.first(capacity)
      byes = pool.drop(capacity)
    else
      playing = pool
      byes = []
    end

    playing.each_slice(2).with_index do |(player1, player2), index|
      match = matches[index]
      next unless match

      if player2
        match.update!(player1: player1, player2: player2, status: "ready")
      else
        # ペアを組む相手がまだいない(奇数人余り)。相手が決まるまで枠だけ確保して待つ。
        match.update!(player1: player1, status: "pending")
      end
    end

    byes
  end
end
