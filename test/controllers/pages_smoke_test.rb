require "test_helper"

# ルートは存在するがテンプレート/アクションが無い、という組み合わせ抜けを検出するための
# 一覧チェック。実際に一度、tournaments#index にビューが無いまま気づかず残ってしまった
# ことがあったため、主要なGETページをひと通り叩いて :success を確認する。
class PagesSmokeTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(name: "smoke-admin", email_address: "smoke-admin@example.com", password: "password123", admin: true)
    @player = User.create!(name: "smoke-player", email_address: "smoke-player@example.com", password: "password123")
    @tournament = @admin.tournaments.create!(name: "Smoke Tournament", status: "draft")
    @tournament.participants.create!(user: @player)
    @tournament.participants.create!(user: @admin)
    BracketGenerator.new(@tournament).generate!
  end

  test "public pages render without signing in" do
    get root_path
    assert_response :success

    get about_path
    assert_response :success

    get new_session_path
    assert_response :success

    get new_registration_path
    assert_response :success

    get new_password_path
    assert_response :success
  end

  test "signed-in pages render for a regular participant" do
    sign_in_as @player

    get root_path
    assert_response :success

    get tournaments_path
    assert_response :success

    get tournament_path(@tournament)
    assert_response :success

    get tournament_path(@tournament, view: "mine")
    assert_response :success

    get tournament_path(@tournament, view: "full")
    assert_response :success

    get my_match_path
    assert_response :success

    get users_path
    assert_response :success

    get user_path(@player)
    assert_response :success
  end

  test "admin-only pages render for an admin" do
    sign_in_as @admin

    get new_tournament_path
    assert_response :success

    draft_tournament = @admin.tournaments.create!(name: "Editable draft", status: "draft")
    get edit_tournament_path(draft_tournament)
    assert_response :success
  end
end
