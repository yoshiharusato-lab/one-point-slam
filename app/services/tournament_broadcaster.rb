class TournamentBroadcaster
  def initialize(tournament)
    @tournament = tournament
  end

  def call
    tournament = @tournament.reload

    Turbo::StreamsChannel.broadcast_replace_to(
      tournament,
      target: "bracket",
      partial: "tournaments/bracket",
      locals: { tournament: tournament, viewing_user: nil }
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      tournament,
      target: "tournament_status",
      partial: "tournaments/status",
      locals: { tournament: tournament }
    )

    tournament.participants.includes(:user).find_each do |participant|
      Turbo::StreamsChannel.broadcast_replace_to(
        [ tournament, participant.user ],
        target: "my_match",
        partial: "tournaments/my_match",
        locals: { tournament: tournament, viewing_user: participant.user }
      )
    end
  end
end
