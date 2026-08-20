class Report < ApplicationRecord
  belongs_to :match
  belongs_to :reporter, class_name: "Participant"
  belongs_to :chosen_winner, class_name: "Participant"

  validates :reporter_id, uniqueness: { scope: :match_id }
  validate :reporter_is_a_player_in_the_match
  validate :chosen_winner_is_a_player_in_the_match

  private

  def reporter_is_a_player_in_the_match
    return unless match && reporter

    unless [ match.player1_id, match.player2_id ].include?(reporter_id)
      errors.add(:reporter, "はこの試合の参加者ではありません")
    end
  end

  def chosen_winner_is_a_player_in_the_match
    return unless match && chosen_winner

    unless [ match.player1_id, match.player2_id ].include?(chosen_winner_id)
      errors.add(:chosen_winner, "は試合の参加者である必要があります")
    end
  end
end
