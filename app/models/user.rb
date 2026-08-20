class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :participants, dependent: :destroy
  has_many :tournaments, foreign_key: :creator_id, dependent: :destroy, inverse_of: :creator

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true

  scope :participants, -> { where(admin: false) }

  def admin?
    admin
  end
end
