class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :participants, dependent: :destroy
  has_many :tournaments, foreign_key: :creator_id, dependent: :destroy, inverse_of: :creator
  has_one_attached :avatar

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # 名前・メールアドレスの形式チェックは、その項目自体を変更するとき(新規登録を含む)
  # だけ行う。この形式が導入される前に作られたアカウント(学籍番号+氏名でない名前や
  # @student.gs.chiba-u.jp 以外のメールなど)が、アバター画像や参加確認の回答といった
  # 無関係な項目を更新しようとしただけで、昔からある名前/メールのせいで保存自体が
  # 失敗してしまう(実際にこれが原因でアバター画像の変更が反映されない不具合になった)
  # のを防ぐため。
  validates :name, presence: true, format: {
    with: /\A[0-9]{2}[\s　]+\S.*\z/,
    message: "は「学籍番号(2桁) 氏名」の形式で入力してください(例: 22 山田太郎)"
  }, if: -> { new_record? || will_save_change_to_name? }
  validates :email_address, presence: true, uniqueness: true, format: {
    with: /\A[A-Za-z0-9._%+-]+@student\.gs\.chiba-u\.jp\z/,
    message: "は@student.gs.chiba-u.jp の形式で入力してください"
  }, if: -> { new_record? || will_save_change_to_email_address? }

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
