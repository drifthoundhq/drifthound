class OauthCallbacksController < ApplicationController
  def github_redirect
    unless github_enabled?
      redirect_to login_path, alert: "GitHub authentication is not enabled"
      return
    end

    state = SecureRandom.hex(24)
    session[:oauth_state] = state

    redirect_to Oauth::GithubService.authorization_url(
      state: state,
      redirect_uri: auth_github_callback_url
    ), allow_other_host: true
  end

  def github
    unless github_enabled?
      redirect_to login_path, alert: "GitHub authentication is not enabled"
      return
    end

    service = Oauth::GithubService.new(
      code: params[:code],
      state: params[:state],
      session_state: session.delete(:oauth_state)
    )

    user = service.authenticate
    session[:user_id] = user.id
    redirect_to root_path, notice: "Logged in successfully via GitHub"
  rescue Oauth::BaseService::InvalidStateError
    redirect_to login_path, alert: "Invalid authentication state. Please try again."
  rescue Oauth::BaseService::TokenExchangeError => e
    Rails.logger.error "GitHub OAuth token exchange failed: #{e.message}"
    redirect_to login_path, alert: "GitHub authentication failed. Please try again."
  rescue Oauth::BaseService::OrganizationAccessError => e
    Rails.logger.warn "GitHub OAuth access denied: #{e.message}"
    redirect_to login_path, alert: "Access denied. You must be a member of a configured team."
  rescue Oauth::BaseService::UserInfoError => e
    Rails.logger.error "GitHub OAuth user info failed: #{e.message}"
    redirect_to login_path, alert: "Failed to retrieve user information from GitHub."
  rescue Oauth::BaseService::OauthError => e
    Rails.logger.error "GitHub OAuth error: #{e.message}"
    redirect_to login_path, alert: "Authentication failed. Please try again."
  end

  def oidc_redirect
    redirect_to login_path, alert: "SSO authentication is not enabled"
  end

  def oidc
    unless oidc_enabled?
      redirect_to login_path, alert: "SSO authentication is not enabled"
      return
    end

    user = Oauth::OidcService.new(request.env["omniauth.auth"]).authenticate
    reset_session
    session[:user_id] = user.id
    redirect_to root_path, notice: "Logged in successfully via SSO"
  rescue Oauth::OidcService::EmailTakenError
    Rails.logger.warn "OIDC login refused: email already belongs to another account"
    redirect_to login_path, alert: "An account with this email address already exists. Sign in the way you usually do, or ask an admin for help."
  rescue Oauth::BaseService::OrganizationAccessError => e
    Rails.logger.warn "OIDC access denied: #{e.message}"
    redirect_to login_path, alert: "Access denied. You must be a member of a configured group."
  rescue Oauth::BaseService::UserInfoError => e
    Rails.logger.warn "OIDC user info rejected: #{e.message}"
    redirect_to login_path, alert: "Your identity provider did not return a usable profile. #{e.message}."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    Rails.logger.error "OIDC user could not be saved: #{e.class}"
    redirect_to login_path, alert: "SSO authentication failed. Please try again."
  end

  def failure
    Rails.logger.warn "OIDC authentication failed: #{params[:message].to_s.truncate(100)}"
    redirect_to login_path, alert: "SSO authentication failed. Please try again."
  end

  private

  def github_enabled?
    Rails.application.config.oauth[:github][:enabled]
  end

  def oidc_enabled?
    Rails.application.config.oidc[:enabled]
  end
end
