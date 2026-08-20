class Participant < ApplicationRecord
  belongs_to :tournament
  belongs_to :user
  has_many :matches_as_player1, class_name: "Match", foreign_key: :player1_id, dependent: :nullify, inverse_of: :player1
  has_many :matches_as_player2, class_name: "Match", foreign_key: :player2_id, dependent: :nullify, inverse_of: :player2
  has_many :matches_won, class_name: "Match", foreign_key: :winner_id, dependent: :nullify, inverse_of: :winner
  has_many :reports, foreign_key: :reporter_id, dependent: :destroy, inverse_of: :reporter

  validates :display_name, presence: true
  validates :user_id, uniqueness: { scope: :tournament_id }

  before_validation :set_display_name, on: :create

  def label
    display_name
  end

  def champion?
    tournament.completed? && tournament.champion&.id == id
  end

  def eliminated?
    matches.any? { |match| match.completed? && match.winner_id != id }
  end

  def next_match
    return nil if champion? || eliminated?

    matches.find { |match| !match.completed? }
  end

  # 1回戦をシード(不戦勝)で免除され、まだ対戦相手(1回戦の勝者)が決まっていない状態。
  def waiting_first_round?
    first_match = matches.first
    first_match.present? && first_match.round > 1 && !first_match.playable?
  end

  def opponent_in(match)
    return nil unless match

    if match.player1_id == id
      match.player2
    elsif match.player2_id == id
      match.player1
    end
  end

  def matches
    tournament.matches.involving_participant(self).ordered
  end

  def defeated_by
    losing_match&.winner
  end

  def losing_match
    matches.find { |match| match.completed? && match.winner_id != id }
  end

  def advanced?
    !eliminated? && !champion? && matches.any? { |match| match.completed? && match.winner_id == id }
  end

  private

  def set_display_name
    self.display_name ||= user&.name
  end
end
