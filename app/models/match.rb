class Match < ApplicationRecord
  STATUSES = %w[pending ready completed bye].freeze

  belongs_to :tournament
  belongs_to :player1, class_name: "Participant", optional: true
  belongs_to :player2, class_name: "Participant", optional: true
  belongs_to :winner, class_name: "Participant", optional: true
  has_many :reports, dependent: :destroy

  validates :round, :position, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :position, uniqueness: { scope: [ :tournament_id, :round ] }

  scope :ordered, -> { order(:round, :position) }
  scope :involving_participant, ->(participant) {
    where(player1_id: participant.id).or(where(player2_id: participant.id))
  }

  def playable?
    status == "ready" && player1.present? && player2.present?
  end

  def completed?
    status.in?(%w[completed bye])
  end

  def involves?(user)
    [ player1, player2 ].compact.any? { |participant| participant.user_id == user.id }
  end

  def opponent_of(user)
    return nil unless involves?(user)

    if player1&.user_id == user.id
      player2
    else
      player1
    end
  end

  # 両者(player1側・player2側)の自己申告が一致したときだけ勝者を確定する。
  # 一致するまでは何度でも申告をやり直せるが、確定後(status: completed)は変更を受け付けない。
  def submit_report!(reporter, chosen_winner)
    raise ArgumentError, "試合はまだ開始できません" unless playable?
    raise ArgumentError, "この試合の参加者ではありません" unless [ player1, player2 ].include?(reporter)
    raise ArgumentError, "勝者は試合の参加者である必要があります" unless [ player1, player2 ].include?(chosen_winner)

    transaction do
      report = reports.find_or_initialize_by(reporter: reporter)
      report.chosen_winner = chosen_winner
      report.save!

      resolve_reports!
    end
  end

  def mismatched_reports?
    votes = reports.pluck(:reporter_id, :chosen_winner_id).to_h
    votes.key?(player1_id) && votes.key?(player2_id) && votes[player1_id] != votes[player2_id]
  end

  def report_by(participant)
    return nil unless participant

    reports.find { |r| r.reporter_id == participant.id }
  end

  def personal_round_label(participant)
    PersonalRoundLabel.for_match(self, participant)
  end

  def round_label
    total_rounds = tournament.round_count
    remaining = total_rounds - round + 1

    case remaining
    when 1 then "決勝"
    when 2 then "準決勝"
    when 3 then "準々決勝"
    else "#{remaining}回戦"
    end
  end

  private

  def resolve_reports!
    votes = reports.reload.pluck(:reporter_id, :chosen_winner_id).to_h
    return unless votes.key?(player1_id) && votes.key?(player2_id)
    return unless votes[player1_id] == votes[player2_id]

    winner_participant = votes[player1_id] == player1_id ? player1 : player2
    update!(winner: winner_participant, status: "completed")
    BracketAdvancer.on_match_complete(self)
    tournament.update!(status: "completed") if final_match? && tournament.champion.present?
  end

  def final_match?
    round == tournament.round_count
  end
end
