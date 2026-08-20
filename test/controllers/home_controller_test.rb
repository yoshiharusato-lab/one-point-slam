require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "about page is public" do
    get about_path
    assert_response :success
  end

  test "root page is public" do
    get root_path
    assert_response :success
  end

  test "my_match requires authentication" do
    get my_match_path
    assert_redirected_to new_session_path
  end

  test "my_match renders when signed in with no active tournament" do
    user = User.create!(name: "solo", email_address: "solo@example.com", password: "password123")
    sign_in_as user

    get my_match_path

    assert_response :success
  end

  test "my_match renders the participant's next match when in an active tournament" do
    admin = User.create!(name: "admin", email_address: "hc-admin@example.com", password: "password123", admin: true)
    player = User.create!(name: "player", email_address: "hc-player@example.com", password: "password123")
    opponent = User.create!(name: "opponent", email_address: "hc-opponent@example.com", password: "password123")

    tournament = admin.tournaments.create!(name: "HC", status: "draft")
    tournament.participants.create!(user: player)
    tournament.participants.create!(user: opponent)
    BracketGenerator.new(tournament).generate!

    sign_in_as player

    get my_match_path

    assert_response :success
    assert_select "h2", text: "あなたの次の対戦"
  end
end
