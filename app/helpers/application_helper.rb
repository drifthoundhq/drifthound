module ApplicationHelper
  def github_oauth_enabled?
    Rails.application.config.oauth[:github][:enabled]
  end

  def oidc_enabled?
    Rails.application.config.oidc[:enabled]
  end

  def oidc_button_label
    Rails.application.config.oidc[:button_label]
  end
end
