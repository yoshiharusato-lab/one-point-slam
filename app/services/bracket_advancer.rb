class BracketAdvancer
  def self.on_round_complete(tournament, round)
    next_round = round + 1
    return if next_round > tournament.round_count

    round_matches = tournament.matches.where(round: round)
    return unless round_matches.all?(&:completed?)

    next_matches = tournament.matches.where(round: next_round).order(:position).to_a
    return if next_matches.empty?

    new_winners = round_matches.order(:position).map(&:winner).compact

    remaining_byes = populate_round(next_matches, new_winners)

    next_next = next_round + 1
    return if remaining_byes.empty? || next_next > tournament.round_count

    later_matches = tournament.matches.where(round: next_next).order(:position).to_a
    populate_round(later_matches, remaining_byes)
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

  # シード(不戦勝)を対戦カードごとにできるだけ1人ずつ、順番に割り振る(左右のバランスを保つため)。
  # 対戦カードの数よりシードの人数が多いときだけ、2周目で同じ枠の2人目として入る
  # (その場合はシード同士の対戦になるが、これは人数的に避けられない)。
  def self.assign_byes_evenly(matches, byes)
    return if matches.empty? || byes.empty?

    byes.each_with_index do |bye, index|
      match = matches[index % matches.size]

      if match.player1.blank?
        match.update!(player1: bye, status: match.player2.present? ? "ready" : "pending")
      else
        match.update!(player2: bye, status: "ready")
      end
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
