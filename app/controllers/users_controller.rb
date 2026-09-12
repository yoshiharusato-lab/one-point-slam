class UsersController < ApplicationController
  before_action :set_user, only: %i[ show update ]

  def index
    @users = User.participants.with_attached_avatar.order(:name)
  end

  def show
    @participations = @user.participants
      .joins(:tournament)
      .where.not(tournaments: { status: "draft" })
      .includes(:tournament)
      .order(created_at: :desc)
  end

  def update
    unless @user == current_user
      redirect_to @user, alert: "自分以外のプロフィール画像は変更できません"
      return
    end

    avatar = params.dig(:user, :avatar)
    if avatar.present? && !valid_avatar?(avatar)
      redirect_to @user, alert: "画像ファイル(PNG/JPEG/GIF/WEBP、5MB以内)を選んでください"
      return
    end

    @user.update!(profile_params)
    redirect_to @user, notice: "更新しました"
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def profile_params
    params.require(:user).permit(:avatar, :day2_attending, :day3_attending)
  end

  def valid_avatar?(avatar)
    avatar.respond_to?(:content_type) &&
      User::AVATAR_CONTENT_TYPES.include?(avatar.content_type) &&
      avatar.size <= User::AVATAR_MAX_BYTES
  end
end
