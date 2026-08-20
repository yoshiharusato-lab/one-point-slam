class ReportsController < ApplicationController
  before_action :set_match

  def create
    return unless @match

    reporter = @match.tournament.participants.find_by(user: current_user)
    unless reporter
      redirect_to @match.tournament, alert: "この試合の参加者ではありません"
      return
    end

    chosen_winner = @match.tournament.participants.find_by(id: params[:chosen_winner_id])
    @match.submit_report!(reporter, chosen_winner)

    broadcast_updates
    redirect_to tournament_path(@match.tournament, view: "mine"), notice: report_notice
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to (@match&.tournament || root_path), alert: e.message
  end

  private

  def set_match
    @match = Match.find_by(id: params[:match_id])
    redirect_to root_path, alert: "試合が見つかりません。" unless @match
  end

  def report_notice
    @match.completed? ? "勝敗が確定しました" : "結果を報告しました。相手の報告を待っています"
  end

  def broadcast_updates
    TournamentBroadcaster.new(@match.tournament).call
  end
end
