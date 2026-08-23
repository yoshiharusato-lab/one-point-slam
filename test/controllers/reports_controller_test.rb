require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(name: "1 admin", email_address: "rc-admin@student.gs.chiba-u.jp", password: "password123", admin: true)
    @tournament = @admin.tournaments.create!(name: "RC", status: "draft")

    @user1 = User.create!(name: "1 p1", email_address: "rc-p1@student.gs.chiba-u.jp", password: "password123")
    @user2 = User.create!(name: "1 p2", email_address: "rc-p2@student.gs.chiba-u.jp", password: "password123")
    @outsider_user = User.create!(name: "1 outsider", email_address: "rc-outsider@student.gs.chiba-u.jp", password: "password123")

    @tournament.participants.create!(user: @user1)
    @tournament.participants.create!(user: @user2)

    BracketGenerator.new(@tournament).generate!
    @match = @tournament.matches.find_by(round: 1, position: 0)
  end

  test "a player can report the winner of their own match" do
    sign_in_as @user1
    reporter = @tournament.participants.find_by(user: @user1)

    post match_report_path(@match), params: { chosen_winner_id: @match.player1_id }

    assert_redirected_to @tournament
    @match.reload
    assert_not @match.completed?
    assert_equal @match.player1_id, @match.report_by(reporter).chosen_winner_id
  end

  test "a user who is not a participant of the tournament cannot report" do
    sign_in_as @outsider_user

    assert_no_difference "Report.count" do
      post match_report_path(@match), params: { chosen_winner_id: @match.player1_id }
    end

    assert_redirected_to @tournament
    follow_redirect!
    assert_match(/参加者ではありません/, flash[:alert].to_s)
  end

  test "a participant cannot report on someone else's match" do
    other_user1 = User.create!(name: "1 op1", email_address: "rc-op1@student.gs.chiba-u.jp", password: "password123")
    other_user2 = User.create!(name: "1 op2", email_address: "rc-op2@student.gs.chiba-u.jp", password: "password123")
    other_tournament = @admin.tournaments.create!(name: "RC-other", status: "draft")
    other_tournament.participants.create!(user: other_user1)
    other_tournament.participants.create!(user: other_user2)
    BracketGenerator.new(other_tournament).generate!
    other_match = other_tournament.matches.find_by(round: 1, position: 0)

    sign_in_as @user1

    assert_no_difference "Report.count" do
      post match_report_path(other_match), params: { chosen_winner_id: other_match.player1_id }
    end

    assert_redirected_to other_tournament
  end

  test "both players reporting the same winner confirms the match" do
    sign_in_as @user1
    post match_report_path(@match), params: { chosen_winner_id: @match.player1_id }

    sign_out
    sign_in_as @user2
    post match_report_path(@match), params: { chosen_winner_id: @match.player1_id }

    @match.reload
    assert @match.completed?
    assert_equal @match.player1, @match.winner
  end

  test "reporting from the my_match page redirects back there instead of the tournament" do
    sign_in_as @user1

    post match_report_path(@match),
      params: { chosen_winner_id: @match.player1_id },
      headers: { "HTTP_REFERER" => my_match_url }

    assert_redirected_to my_match_url
  end

  test "requires authentication" do
    post match_report_path(@match), params: { chosen_winner_id: @match.player1_id }

    assert_redirected_to new_session_path
  end
end
