require "test_helper"

class TournamentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(name: "admin", email_address: "tc-admin@example.com", password: "password123", admin: true)
    @player = User.create!(name: "player", email_address: "tc-player@example.com", password: "password123")
    @other_player = User.create!(name: "other", email_address: "tc-other@example.com", password: "password123")
  end

  test "a non-admin cannot reach the new tournament form" do
    sign_in_as @player

    get new_tournament_path

    assert_redirected_to root_path
  end

  test "a non-admin cannot create a tournament even by posting directly" do
    sign_in_as @player

    assert_no_difference "Tournament.count" do
      post tournaments_path, params: { tournament: { name: "Hijacked" }, participant_user_ids: [ @player.id ] }
    end

    assert_redirected_to root_path
  end

  test "an admin can create a tournament and add participants" do
    sign_in_as @admin

    assert_difference "Tournament.count", 1 do
      post tournaments_path, params: {
        tournament: { name: "Admin Cup" },
        participant_user_ids: [ @player.id, @other_player.id ]
      }
    end

    tournament = Tournament.last
    assert_equal "draft", tournament.status
    assert_equal [ @player.id, @other_player.id ].sort, tournament.participants.pluck(:user_id).sort
  end

  test "starting a tournament generates the bracket" do
    sign_in_as @admin
    tournament = @admin.tournaments.create!(name: "Startable", status: "draft")
    tournament.participants.create!(user: @player)
    tournament.participants.create!(user: @other_player)

    post start_tournament_path(tournament)

    tournament.reload
    assert tournament.active?
    assert tournament.matches.exists?
  end

  test "a non-admin cannot start a tournament" do
    sign_in_as @player
    tournament = @admin.tournaments.create!(name: "Not yours", status: "draft")
    tournament.participants.create!(user: @player)
    tournament.participants.create!(user: @other_player)

    post start_tournament_path(tournament)

    tournament.reload
    assert tournament.draft?
  end
end
