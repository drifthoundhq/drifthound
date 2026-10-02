oidc_list = ->(value) { value.to_s.split(",").map(&:strip).reject(&:blank?) }
oidc_scopes = ENV.fetch("OIDC_SCOPES", "").split(/[\s,]+/).reject(&:blank?)
oidc_scopes = %w[openid email profile] if oidc_scopes.empty?
oidc_app_url = ENV.fetch("APP_URL", "http://localhost:3000").to_s.strip.chomp("/")

Rails.application.config.oidc = {
  enabled: ENV.fetch("OIDC_ENABLED", "false") == "true",
  issuer: ENV["OIDC_ISSUER"].to_s.strip.presence,
  client_id: ENV["OIDC_CLIENT_ID"].to_s.strip.presence,
  client_secret: ENV["OIDC_CLIENT_SECRET"].presence,
  scopes: ([ "openid" ] | oidc_scopes),
  redirect_uri: "#{oidc_app_url}/auth/oidc/callback",
  groups_claim: ENV["OIDC_GROUPS_CLAIM"].to_s.strip.presence || "groups",
  group_mappings: {
    admin: oidc_list.call(ENV["OIDC_ADMIN_GROUPS"]),
    editor: oidc_list.call(ENV["OIDC_EDITOR_GROUPS"]),
    viewer: oidc_list.call(ENV["OIDC_VIEWER_GROUPS"])
  }.select { |_, groups| groups.any? },
  default_role: ENV["OIDC_DEFAULT_ROLE"].to_s.strip.downcase.presence&.to_sym,
  button_label: ENV["OIDC_BUTTON_LABEL"].to_s.strip.presence || "Sign in with SSO"
}

if Rails.application.config.oidc[:enabled]
  oidc_config = Rails.application.config.oidc

  missing = []
  missing << "OIDC_ISSUER" if oidc_config[:issuer].blank?
  missing << "OIDC_CLIENT_ID" if oidc_config[:client_id].blank?
  missing << "OIDC_CLIENT_SECRET" if oidc_config[:client_secret].blank?

  if missing.any?
    raise "OIDC is enabled but missing required environment variables: #{missing.join(', ')}"
  end

  if oidc_config[:default_role] && %i[viewer editor admin].exclude?(oidc_config[:default_role])
    raise "OIDC_DEFAULT_ROLE must be one of: viewer, editor, admin"
  end

  if oidc_config[:group_mappings].empty? && oidc_config[:default_role].nil?
    raise "OIDC is enabled but no group mappings configured. Set at least one of: OIDC_ADMIN_GROUPS, OIDC_EDITOR_GROUPS, OIDC_VIEWER_GROUPS, or set OIDC_DEFAULT_ROLE"
  end
end

OmniAuth.config.logger = Rails.logger

class OidcAuthentication
  def initialize(app)
    @app = app
    oidc_config = Rails.application.config.oidc
    @omniauth = OmniAuth::Builder.new(app) do
      provider :openid_connect,
        name: :oidc,
        issuer: oidc_config[:issuer],
        discovery: true,
        response_type: :code,
        pkce: true,
        scope: oidc_config[:scopes].map(&:to_sym),
        client_options: {
          identifier: oidc_config[:client_id],
          secret: oidc_config[:client_secret],
          redirect_uri: oidc_config[:redirect_uri]
        }
    end.to_app
  end

  def call(env)
    Rails.application.config.oidc[:enabled] ? @omniauth.call(env) : @app.call(env)
  end
end

Rails.application.config.middleware.use OidcAuthentication
