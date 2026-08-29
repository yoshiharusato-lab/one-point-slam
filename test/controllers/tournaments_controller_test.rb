require "test_helper"

class TournamentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(name: "10 admin", email_address: "tc-admin@student.gs.chiba-u.jp", password: "password123", admin: true)
    @player = User.create!(name: "10 player", email_address: "tc-player@student.gs.chiba-u.jp", password: "password123")
    @other_player = User.create!(name: "10 other", email_address: "tc-other@student.gs.chiba-u.jp", password: "password123")
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

  test "a bye waiting in round 2 is still visible (as waiting, not decided) before its round-1 match ends" do
    sign_in_as @admin
    tournament = @admin.tournaments.create!(name: "Bye6", status: "draft")
    6.times do |i|
      user = User.create!(name: "10 bye-#{i}", email_address: "tc-bye-#{i}@student.gs.chiba-u.jp", password: "password123")
      tournament.participants.create!(user: user)
    end
    BracketGenerator.new(tournament).generate!

    bye_names = tournament.matches.where(round: 2).map { |m| m.player1&.display_name }.compact
    assert_equal 2, bye_names.size

    get tournament_path(tournament)
    # 全6人が(不戦勝で待機中の2人も含めて)表示されていること。
    tournament.participants.each do |participant|
      assert_includes response.body, participant.display_name, "participant '#{participant.display_name}' should be visible in the bracket"
    end

    round1 = tournament.matches.where(round: 1).order(:position).to_a
    round1.each { |m| [ m.player1, m.player2 ].each { |p| sign_in_as p.user; post match_report_path(m), params: { chosen_winner_id: m.player1_id } } }
    sign_in_as @admin

    get tournament_path(tournament)
    bye_names.each do |name|
      assert_includes response.body, name, "round-2 bye '#{name}' should still be visible once round1 has decided their opponent"
    end
  end
end
