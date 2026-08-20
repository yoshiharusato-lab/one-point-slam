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

  # avatar が未設定の場合は共通のデフォルト画像を表示する。
  # (この環境には画像変換ライブラリ(libvips等)が無いため、variantでのリサイズはせず
  #  元画像をそのまま出し、表示サイズはCSS側の width/height/object-fit で揃えている)
  def user_avatar_tag(user, css_class: "avatar")
    if user&.avatar&.attached?
      image_tag user.avatar, class: css_class, alt: user.name
    else
      image_tag "default_avatar.jpg", class: css_class, alt: user&.name.to_s
    end
  end
end
