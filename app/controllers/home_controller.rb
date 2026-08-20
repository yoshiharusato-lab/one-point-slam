class HomeController < ApplicationController
  allow_unauthenticated_access only: %i[ index about ]

  def index
    if authenticated?
      @tournaments = Tournament.recent
      @my_tournaments = current_user.participants.includes(:tournament).map(&:tournament).uniq
    end
  end

  def about
  end

  def my_match
    @participant = current_user.participants
      .joins(:tournament)
      .where(tournaments: { status: "active" })
      .order("tournaments.started_at DESC")
      .first
    @tournament = @participant&.tournament
  end
end
