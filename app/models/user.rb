class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :participants, dependent: :destroy
  has_many :tournaments, foreign_key: :creator_id, dependent: :destroy, inverse_of: :creator
  has_one_attached :avatar

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true, format: {
    with: /\A[0-9]+[\s　]+\S.*\z/,
    message: "は「学籍番号 氏名」の形式で入力してください(例: 12345678 千葉太郎)"
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
end
