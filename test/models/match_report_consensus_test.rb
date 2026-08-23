require "test_helper"

class MatchReportConsensusTest < ActiveSupport::TestCase
  setup do
    @admin = User.create!(name: "1 admin", email_address: "consensus-admin@student.gs.chiba-u.jp", password: "password123", admin: true)
    @tournament = @admin.tournaments.create!(name: "Consensus", status: "draft")

    3.times do |i|
      user = User.create!(name: "1 player#{i}", email_address: "consensus-p#{i}@student.gs.chiba-u.jp", password: "password123")
      @tournament.participants.create!(user: user)
    end

    BracketGenerator.new(@tournament).generate!
    # 3人トーナメントでは1人がシード(不戦勝)で1回戦を戦わない。
    # その人を「この試合の参加者ではない人」として権限チェックのテストに使う。
    @match = @tournament.matches.find_by(round: 1)
    @outsider = @tournament.participants.find { |p| p.id != @match.player1_id && p.id != @match.player2_id }
  end

  test "confirms the winner only once both sides report the same participant" do
    @match.submit_report!(@match.player1, @match.player1)
    assert_not @match.completed?

    @match.submit_report!(@match.player2, @match.player1)
    assert @match.completed?
    assert_equal @match.player1, @match.winner
  end

  test "does not confirm a winner when the two reports disagree" do
    @match.submit_report!(@match.player1, @match.player1)
    @match.submit_report!(@match.player2, @match.player2)

    assert_not @match.completed?
    assert_nil @match.winner
    assert @match.mismatched_reports?
  end

  test "resubmitting a report can resolve a mismatch" do
    @match.submit_report!(@match.player1, @match.player1)
    @match.submit_report!(@match.player2, @match.player2)
    assert_not @match.completed?

    @match.submit_report!(@match.player2, @match.player1)

    assert @match.completed?
    assert_equal @match.player1, @match.winner
  end

  test "rejects a report from a participant who is not in this match" do
    error = assert_raises(ArgumentError) do
      @match.submit_report!(@outsider, @match.player1)
    end
    assert_match(/参加者ではありません/, error.message)
  end

  test "rejects a chosen winner who is not a player in this match" do
    error = assert_raises(ArgumentError) do
      @match.submit_report!(@match.player1, @outsider)
    end
    assert_match(/参加者である必要があります/, error.message)
  end

  test "rejects reports on a match that is not playable yet" do
    pending_match = @tournament.matches.where(status: "pending").first

    error = assert_raises(ArgumentError) do
      pending_match.submit_report!(@match.player1, @match.player1)
    end
    assert_match(/試合はまだ開始できません/, error.message)
  end

  test "rejects further reports once the match is completed" do
    @match.submit_report!(@match.player1, @match.player1)
    @match.submit_report!(@match.player2, @match.player1)

    error = assert_raises(ArgumentError) do
      @match.submit_report!(@match.player1, @match.player2)
    end
    assert_match(/試合はまだ開始できません/, error.message)
  end
end
