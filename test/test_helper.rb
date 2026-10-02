ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module OidcTestHelper
  def enable_oidc(**overrides)
    @original_oidc_config = Rails.application.config.oidc
    Rails.application.config.oidc = {
      enabled: true,
      issuer: "https://login.example.com",
      client_id: "drifthound",
      client_secret: "test-client-secret",
      scopes: %w[openid email profile],
      redirect_uri: "http://www.example.com/auth/oidc/callback",
      groups_claim: "groups",
      group_mappings: {
        admin: [ "drift-admins" ],
        editor: [ "drift-editors" ],
        viewer: [ "drift-viewers" ]
      },
      default_role: nil,
      button_label: "Sign in with SSO"
    }.merge(overrides)
    OmniAuth.config.test_mode = true
  end

  def restore_oidc
    Rails.application.config.oidc = @original_oidc_config if @original_oidc_config
    OmniAuth.config.mock_auth[:oidc] = nil
    OmniAuth.config.test_mode = false
  end

  def oidc_auth_hash(sub: "oidc-sub-1", email: "sso.user@example.com", groups: [ "drift-viewers" ], raw_info: {})
    OmniAuth::AuthHash.new(
      provider: "oidc",
      uid: sub,
      info: { email: email },
      extra: { raw_info: { "sub" => sub, "email" => email, "groups" => groups }.merge(raw_info) }
    )
  end

  def mock_oidc_login(**attrs)
    OmniAuth.config.mock_auth[:oidc] = oidc_auth_hash(**attrs)
  end
end
