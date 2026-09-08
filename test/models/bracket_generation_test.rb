require "test_helper"

class BracketGenerationTest < ActiveSupport::TestCase
  def build_tournament(participant_count)
    admin = User.create!(name: "10 admin", email_address: "admin-#{participant_count}@student.gs.chiba-u.jp", password: "password123", admin: true)
    tournament = admin.tournaments.create!(name: "T#{participant_count}", status: "draft")

    participant_count.times do |i|
      user = User.create!(name: "10 user-#{participant_count}-#{i}", email_address: "user-#{participant_count}-#{i}@student.gs.chiba-u.jp", password: "password123")
      tournament.participants.create!(user: user)
    end

    tournament
  end

  # 決勝までプレイし、確定した勝者の名前で毎回報告する(自己申告の一致で勝敗確定)。
  def play_out!(tournament)
    loop do
      match = tournament.matches.ordered.find(&:playable?)
      break unless match

      match.submit_report!(match.player1, match.player1)
      match.submit_report!(match.player2, match.player1)
    end
  end

  # 2〜17人 + 大規模(31〜65人)まで、2の累乗・奇数・非2の累乗の偶数のすべてのパターンで、
  # 最終的にちょうど1人のチャンピオンが決まり、すべての試合が終了することを確認する。
  #
  # 「不完全な試合が残っていない」だけでは不十分(過去に、シード(不戦勝)が絡む組み合わせで
  # 一部の参加者が2回戦以降に一切繋がらず、静かに勝ち上がりから脱落するバグがあった)。
  # 優勝者以外の参加者が必ずどこかで1敗している(=誰も置き去りにされていない)ことまで検証する。
  ((2..17).to_a + [ 31, 32, 33, 50, 63, 64, 65 ]).each do |n|
    test "a #{n}-participant bracket resolves fairly to exactly one champion" do
      tournament = build_tournament(n)
      BracketGenerator.new(tournament).generate!

      assert tournament.active?

      play_out!(tournament)
      tournament.reload

      assert tournament.completed?, "tournament should be completed for n=#{n}"
      assert tournament.champion.present?, "a champion should be decided for n=#{n}"
      assert_equal 0, tournament.matches.where.not(status: %w[completed bye]).count,
        "no match should be left unresolved for n=#{n}"

      losers = tournament.participants.select do |p|
        p.matches.any? { |m| m.completed? && m.winner_id && m.winner_id != p.id }
      end
      assert_equal n - 1, losers.size,
        "every participant except the champion should lose exactly one match for n=#{n}"
    end
  end

  test "byes are spread one per match instead of paired against each other" do
    tournament = build_tournament(6)
    BracketGenerator.new(tournament).generate!

    round2 = tournament.matches.where(round: 2).order(:position).to_a
    assert_equal 2, round2.size

    # 6人なら1回戦は2試合・シードは2人。シード同士を同じ枠に組んでしまうと、
    # 片方の準決勝が1回戦の結果を待たずに埋まってしまうため、1人ずつ別の枠で待たせる。
    round2.each do |match|
      seated = [ match.player1, match.player2 ].compact
      assert_equal 1, seated.size, "each round-2 match should start with exactly one bye waiting, not two"
      assert_equal "pending", match.status
    end

    round1 = tournament.matches.where(round: 1).order(:position).to_a
    round1.each { |m| m.submit_report!(m.player1, m.player1); m.submit_report!(m.player2, m.player1) }

    tournament.matches.where(round: 2).order(:position).each_with_index do |match, i|
      round1_winner = round1[i].winner
      assert_includes [ match.player1, match.player2 ], round1_winner,
        "the bye waiting in round-2 match #{i} should face that side's round-1 winner, not the other bye"
    end
  end

  # 表示側(BracketHelper#bracket_left_right_center)は各ラウンドの対戦カードを
  # 前半/後半で左右に振り分けているだけなので、勝ち上がりの実装側もこれと同じ
  # 比率で左右を保たないと、「準々決勝の左側で勝ったのに、準決勝を見たら左側には
  # 全く関係ない(その試合の勝者を待っていたはずのない)人が既に入っている」という
  # ズレが起きる。1回戦の試合数と2回戦の対戦カード数が一致しない(例: 10人)場合に
  # 特に起きやすいので、そのあたりを広めにカバーする。
  def side_split(matches)
    half = matches.size / 2
    [ matches.first(half), matches.drop(half) ]
  end

  ((3..17).to_a + [ 31, 33, 63 ]).each do |n|
    test "a #{n}-participant bracket never lets a winner cross to the other side of the bracket" do
      tournament = build_tournament(n)
      BracketGenerator.new(tournament).generate!
      assert tournament.round_count.positive?

      # 決勝(最終ラウンド)は左右に分けず中央に1試合だけ表示するため、
      # 「準決勝→決勝」の遷移はこのチェックの対象外(両側の勝者が同じ1試合に集まるのが正しい)。
      (1...(tournament.round_count - 1)).each do |round|
        round_matches = tournament.matches.where(round: round).order(:position).to_a
        next_matches = tournament.matches.where(round: round + 1).order(:position).to_a
        left_matches, right_matches = side_split(round_matches)
        left_next, right_next = side_split(next_matches)

        left_matches.each { |m| next unless m.playable?; m.submit_report!(m.player1, m.player1); m.submit_report!(m.player2, m.player1) }
        right_matches.each { |m| next unless m.playable?; m.submit_report!(m.player1, m.player1); m.submit_report!(m.player2, m.player1) }

        left_seated = left_next.flat_map { |m| [ m.reload.player1, m.player2 ] }.compact
        right_seated = right_next.flat_map { |m| [ m.reload.player1, m.player2 ] }.compact

        left_matches.each do |m|
          next unless m.winner
          assert_includes left_seated, m.winner,
            "n=#{n}, round #{round}: the left side's winner #{m.winner.user.name} must appear on the left side of round #{round + 1}, not the right"
        end
        right_matches.each do |m|
          next unless m.winner
          assert_includes right_seated, m.winner,
            "n=#{n}, round #{round}: the right side's winner #{m.winner.user.name} must appear on the right side of round #{round + 1}, not the left"
        end
      end
    end
  end

  test "a winner appears in the next round immediately, without waiting for sibling matches" do
    tournament = build_tournament(8)
    BracketGenerator.new(tournament).generate!

    round1 = tournament.matches.where(round: 1).order(:position).to_a
    only_match = round1.first
    winner = only_match.player1
    only_match.submit_report!(only_match.player1, winner)
    only_match.submit_report!(only_match.player2, winner)

    other_round1_matches = round1.drop(1)
    assert other_round1_matches.all? { |m| m.reload.playable? },
      "the other round-1 matches should be untouched and still awaiting their own result"

    round2 = tournament.matches.where(round: 2).order(:position).to_a
    assert_includes round2.flat_map { |m| [ m.player1, m.player2 ] }, winner,
      "the winner should already occupy their round-2 slot, without waiting for the other round-1 matches"
  end

  test "generate! refuses to start with fewer than 2 participants" do
    tournament = build_tournament(1)

    assert_raises(ArgumentError) { BracketGenerator.new(tournament).generate! }
  end

  test "generate! refuses to run twice on the same tournament" do
    tournament = build_tournament(4)
    BracketGenerator.new(tournament).generate!

    assert_raises(ArgumentError) { BracketGenerator.new(tournament).generate! }
  end
end
