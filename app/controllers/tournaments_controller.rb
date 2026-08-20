class TournamentsController < ApplicationController
  include BracketHelper

  before_action :set_tournament, only: %i[ show edit update destroy start ]
  before_action :require_admin!, only: %i[ new create edit update destroy start ]

  def index
    @tournaments = Tournament.recent
  end

  def show
    @participant = @tournament.participants.find_by(user: current_user)
    @view = params[:view].presence_in(%w[mine full]) || tournament_default_view(@tournament, current_user)
  end

  def new
    @tournament = Tournament.new
    @users = User.participants.order(:name)
  end

  def create
    @tournament = current_user.tournaments.build(tournament_params)
    @tournament.status = "draft"

    if @tournament.save
      add_participants_from_params
      redirect_to @tournament, notice: "トーナメントを作成しました。開始タイミングを選んでください。"
    else
      @users = User.participants.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @users = User.participants.order(:name)
  end

  def update
    if @tournament.draft? && @tournament.update(tournament_params)
      update_participants_from_params if params[:participant_user_ids]
      redirect_to @tournament, notice: "トーナメントを更新しました"
    else
      @users = User.participants.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tournament.destroy
    redirect_to tournaments_path, notice: "トーナメントを削除しました"
  end

  def start
    unless @tournament.draft?
      redirect_to @tournament, alert: "すでに開始済みです"
      return
    end

    BracketGenerator.new(@tournament).generate!
    TournamentBroadcaster.new(@tournament).call
    redirect_to @tournament, notice: "トーナメントを開始しました！"
  rescue ArgumentError => e
    redirect_to @tournament, alert: e.message
  end

  private

  def set_tournament
    @tournament = Tournament.find_by(id: params[:id])
    redirect_to root_path, alert: "トーナメントが見つかりません。トップページから再度お選びください。" unless @tournament
  end

  def tournament_params
    params.require(:tournament).permit(:name)
  end

  def add_participants_from_params
    user_ids = Array(params[:participant_user_ids]).reject(&:blank?).map(&:to_i)
    User.participants.where(id: user_ids).find_each do |user|
      @tournament.participants.find_or_create_by!(user: user)
    end
  end

  def update_participants_from_params
    user_ids = Array(params[:participant_user_ids]).reject(&:blank?).map(&:to_i)
    @tournament.participants.where.not(user_id: user_ids).destroy_all
    User.participants.where(id: user_ids).find_each do |user|
      @tournament.participants.find_or_create_by!(user: user)
    end
  end
end
