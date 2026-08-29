class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :participants, dependent: :destroy
  has_many :tournaments, foreign_key: :creator_id, dependent: :destroy, inverse_of: :creator
  has_one_attached :avatar

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true, format: {
    with: /\A[0-9]{2}[\s　]+\S.*\z/,
    message: "は「学籍番号(2桁) 氏名」の形式で入力してください(例: 22 佐藤吉遥)"
  }
  validates :email_address, presence: true, uniqueness: true, format: {
    with: /\A[A-Za-z0-9._%+-]+@student\.gs\.chiba-u\.jp\z/,
    message: "は@student.gs.chiba-u.jp の形式で入力してください"
  }

  scope :participants, -> { where(admin: false) }

  AVATAR_CONTENT_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze
  AVATAR_MAX_BYTES = 5.megabytes

  def admin?
    admin
  end

  def day2_attending_label
    attendance_label(day2_attending)
  end

  def day3_attending_label
    attendance_label(day3_attending)
  end

  private

  def attendance_label(value)
    case value
    when true then "する"
    when false then "しない"
    else "未回答"
    end
  end
end
