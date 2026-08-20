class HomeController < ApplicationController
  allow_unauthenticated_access only: :about

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
