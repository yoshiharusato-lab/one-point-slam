module ApplicationHelper
  def tournament_status_label(tournament)
    case tournament.status
    when "draft" then "準備中"
    when "active" then "進行中"
    when "completed" then "終了"
    else tournament.status
    end
  end

  def tournament_status_class(tournament)
    case tournament.status
    when "draft" then "bg-slate-100 text-slate-600"
    when "active" then "bg-emerald-100 text-emerald-700"
    when "completed" then "bg-blue-100 text-blue-700"
    else "bg-slate-100 text-slate-600"
    end
  end

  def match_player_class(participant, match, viewing_user)
    return "text-slate-400 italic" if participant.nil?

    classes = []
    classes << "font-bold text-emerald-700" if match.winner_id == participant.id
    classes << "ring-2 ring-amber-300 rounded px-1" if viewing_user && participant.user_id == viewing_user.id
    classes.join(" ")
  end
end
