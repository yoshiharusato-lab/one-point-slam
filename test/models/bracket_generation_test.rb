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
