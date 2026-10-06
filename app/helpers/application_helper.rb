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

  def encode_url_path(path)
    path.split("/").map { |segment| ERB::Util.url_encode(segment) }.join("/")
  end
end
