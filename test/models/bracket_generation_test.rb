require "test_helper"

class BracketGenerationTest < ActiveSupport::TestCase
  def build_tournament(participant_count)
    admin = User.create!(name: "admin", email_address: "admin-#{participant_count}@example.com", password: "password123", admin: true)
    tournament = admin.tournaments.create!(name: "T#{participant_count}", status: "draft")

    participant_count.times do |i|
      user = User.create!(name: "user-#{participant_count}-#{i}", email_address: "user-#{participant_count}-#{i}@example.com", password: "password123")
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

  # 2〜16人まで、2の累乗・奇数・非2の累乗の偶数のすべてのパターンで、
  # 最終的にちょうど1人のチャンピオンが決まり、すべての試合が終了することを確認する。
  (2..16).each do |n|
    test "a #{n}-participant bracket resolves to exactly one champion" do
      tournament = build_tournament(n)
      BracketGenerator.new(tournament).generate!

      assert tournament.active?

      play_out!(tournament)
      tournament.reload

      assert tournament.completed?, "tournament should be completed for n=#{n}"
      assert tournament.champion.present?, "a champion should be decided for n=#{n}"
      assert_equal 0, tournament.matches.where.not(status: %w[completed bye]).count,
        "no match should be left unresolved for n=#{n}"
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
