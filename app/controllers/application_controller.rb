class ApplicationController < ActionController::Base
  include Authentication
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  private

  def current_user
    Current.user
  end

  def require_admin!
    redirect_to root_path, alert: "管理者アカウントでログインしてください" unless current_user&.admin?
  end

  def record_not_found
    redirect_to root_path, alert: "ページが見つかりません。削除されたか、URLが古くなっている可能性があります。"
  end
end
