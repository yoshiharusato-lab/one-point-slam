require "test_helper"

class PersonalRoundLabelTest < ActiveSupport::TestCase
  def build_tournament(n)
    admin = User.create!(name: "10 admin", email_address: "prl-admin-#{n}@student.gs.chiba-u.jp", password: "password123", admin: true)
    tournament = admin.tournaments.create!(name: "PRL#{n}", status: "draft")

    n.times do |i|
      user = User.create!(name: "10 prl-#{n}-#{i}", email_address: "prl-#{n}-#{i}@student.gs.chiba-u.jp", password: "password123")
      tournament.participants.create!(user: user)
    end

    tournament
  end

  test "a seed's first match counts as round2, not round1" do
    tournament = build_tournament(6)
    BracketGenerator.new(tournament).generate!

    seed_match = tournament.matches.find_by(round: 2)
    seed = seed_match.player1 || seed_match.player2
    assert seed.present?

    assert_equal "第2回戦", PersonalRoundLabel.for_match(seed_match, seed)
    assert_equal "第2回戦待機", PersonalRoundLabel.progress_label(seed)
  end

  test "elimination in round1 shows the round number and opponent" do
    tournament = build_tournament(6)
    BracketGenerator.new(tournament).generate!

    match = tournament.matches.find_by(round: 1)
    loser = match.player1
    winner = match.player2
    match.submit_report!(match.player1, winner)
    match.submit_report!(match.player2, winner)

    assert_equal "第1回戦敗退（#{winner.display_name}）", PersonalRoundLabel.progress_label(loser)
  end

  test "elimination in round2 (a seed's first match) shows 第2回戦敗退" do
    tournament = build_tournament(6)
    BracketGenerator.new(tournament).generate!

    round1 = tournament.matches.where(round: 1).order(:position).to_a
    round1.each { |m| m.submit_report!(m.player1, m.player1); m.submit_report!(m.player2, m.player1) }

    seed_match = tournament.matches.reload.where(round: 2).order(:position).first
    loser = seed_match.player1
    winner = seed_match.player2
    seed_match.submit_report!(seed_match.player1, winner)
    seed_match.submit_report!(seed_match.player2, winner)

    assert_equal "第2回戦敗退（#{winner.display_name}）", PersonalRoundLabel.progress_label(loser)
  end
end
