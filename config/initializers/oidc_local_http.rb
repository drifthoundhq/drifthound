# Local testing only (docker-compose.oidc.yml): the mock identity provider
# speaks plain http, and OIDC discovery builds its URL with SWD.url_builder,
# which defaults to https. Never active outside development.
if Rails.env.development? && ENV["OIDC_ISSUER"].to_s.start_with?("http://")
  SWD.url_builder = URI::HTTP
end
