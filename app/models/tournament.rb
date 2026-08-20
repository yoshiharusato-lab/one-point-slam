class Tournament < ApplicationRecord
  STATUSES = %w[draft active completed].freeze

  belongs_to :creator, class_name: "User"
  has_many :participants, dependent: :destroy
  has_many :users, through: :participants
  has_many :matches, dependent: :destroy

  validates :name, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }

  def draft?
    status == "draft"
  end

  def active?
    status == "active"
  end

  def completed?
    status == "completed"
  end

  def round_count
    return 0 if participants.empty?

    BracketGenerator.round_count(participants.count)
  end

  def champion
    final_match = matches.where(round: round_count).first
    final_match&.winner
  end
end
