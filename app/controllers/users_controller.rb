class UsersController < ApplicationController
  def index
    @users = User.participants.order(:name)
  end

  def show
    @user = User.find(params[:id])
    @participations = @user.participants.includes(:tournament).order(created_at: :desc)
  end
end
