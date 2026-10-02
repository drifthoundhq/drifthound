require "test_helper"

class OidcLoginTest < ActionDispatch::IntegrationTest
  include OidcTestHelper

  setup do
    enable_oidc
  end

  teardown do
    restore_oidc
  end

  def sign_in_with_oidc
    post auth_oidc_path
    assert_redirected_to "/auth/oidc/callback"
    follow_redirect!
  end

  test "login page shows the SSO button with the configured label when enabled" do
    Rails.application.config.oidc[:button_label] = "Sign in with Example SSO"

    get login_path

    assert_response :success
    assert_select "form[action='#{auth_oidc_path}'][method='post'] button", text: "Sign in with Example SSO"
  end

  test "login page hides the SSO button when disabled" do
    Rails.application.config.oidc[:enabled] = false

    get login_path

    assert_response :success
    assert_select "form[action='#{auth_oidc_path}']", count: 0
  end

  test "request phase is refused when disabled" do
    Rails.application.config.oidc[:enabled] = false

    post auth_oidc_path

    assert_redirected_to login_path
    assert_equal "SSO authentication is not enabled", flash[:alert]
  end

  test "callback is refused when disabled" do
    Rails.application.config.oidc[:enabled] = false
    mock_oidc_login

    assert_no_difference "User.count" do
      get auth_oidc_callback_path
    end

    assert_redirected_to login_path
    assert_equal "SSO authentication is not enabled", flash[:alert]
    assert_nil session[:user_id]
  end

  test "first login creates a user matched by provider and sub" do
    mock_oidc_login(sub: "new-sub", email: "New.User@Example.com", groups: [ "drift-viewers" ])

    assert_difference "User.count", 1 do
      sign_in_with_oidc
    end

    user = User.find_by(provider: "oidc", uid: "new-sub")
    assert_not_nil user
    assert_equal "new.user@example.com", user.email
    assert user.viewer?
    assert_not user.can_use_password?
    assert_redirected_to root_path
    assert_equal "Logged in successfully via SSO", flash[:notice]
    assert_equal user.id, session[:user_id]
  end

  test "returning user is found by sub and gets the role from current groups" do
    user = User.create!(email: "returning@example.com", provider: "oidc", uid: "returning-sub", role: :viewer)
    mock_oidc_login(sub: "returning-sub", email: "changed@example.com", groups: [ "drift-admins" ])

    assert_no_difference "User.count" do
      sign_in_with_oidc
    end

    user.reload
    assert user.admin?
    assert_equal "returning@example.com", user.email
    assert_equal user.id, session[:user_id]
  end

  test "highest mapped role wins" do
    mock_oidc_login(groups: [ "drift-viewers", "drift-editors", "unrelated" ])

    sign_in_with_oidc

    assert User.find_by(provider: "oidc", uid: "oidc-sub-1").editor?
  end

  test "groups are read from the configured claim" do
    Rails.application.config.oidc[:groups_claim] = "roles"
    mock_oidc_login(groups: [], raw_info: { "roles" => "drift-admins" })

    sign_in_with_oidc

    assert User.find_by(provider: "oidc", uid: "oidc-sub-1").admin?
  end

  test "user in no mapped group is refused" do
    mock_oidc_login(groups: [ "unrelated" ])

    assert_no_difference "User.count" do
      sign_in_with_oidc
    end

    assert_redirected_to login_path
    assert_equal "Access denied. You must be a member of a configured group.", flash[:alert]
    assert_nil session[:user_id]
  end

  test "user in no mapped group gets the default role when one is set" do
    Rails.application.config.oidc[:default_role] = :viewer
    mock_oidc_login(groups: [])

    sign_in_with_oidc

    assert User.find_by(provider: "oidc", uid: "oidc-sub-1").viewer?
  end

  test "login is refused when the email belongs to another account" do
    admin = users(:admin)
    mock_oidc_login(sub: "other-sub", email: "Admin@Example.com", groups: [ "drift-viewers" ])

    assert_no_difference "User.count" do
      sign_in_with_oidc
    end

    assert_redirected_to login_path
    assert_match "An account with this email address already exists", flash[:alert]
    assert_nil session[:user_id]
    admin.reload
    assert admin.admin?
    assert_nil admin.provider
  end

  test "login is refused when the email belongs to a GitHub user" do
    User.create!(email: "dev@example.com", provider: "github", uid: "12345", role: :editor)
    mock_oidc_login(sub: "dev-sub", email: "dev@example.com")

    assert_no_difference "User.count" do
      sign_in_with_oidc
    end

    assert_match "An account with this email address already exists", flash[:alert]
  end

  test "login is refused when the provider sends no email" do
    mock_oidc_login(email: nil)

    assert_no_difference "User.count" do
      sign_in_with_oidc
    end

    assert_redirected_to login_path
    assert_match "did not return a usable profile", flash[:alert]
  end

  test "login is refused when the email is marked unverified" do
    mock_oidc_login(raw_info: { "email_verified" => false })

    assert_no_difference "User.count" do
      sign_in_with_oidc
    end

    assert_match "did not return a usable profile", flash[:alert]
  end

  test "provider failure redirects to the login page" do
    OmniAuth.config.mock_auth[:oidc] = :invalid_credentials

    post auth_oidc_path
    follow_redirect!

    assert_redirected_to %r{/auth/failure}
    follow_redirect!
    assert_redirected_to login_path
    assert_equal "SSO authentication failed. Please try again.", flash[:alert]
  end

  test "authorization code is filtered from logs" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered = filter.filter("code" => "auth-code", "state" => "abc", "exit_code" => "2")

    assert_equal "[FILTERED]", filtered["code"]
    assert_equal "abc", filtered["state"]
    assert_equal "2", filtered["exit_code"]
  end

  test "request phase requires a valid authenticity token" do
    ActionController::Base.allow_forgery_protection = true

    post auth_oidc_path

    assert_redirected_to %r{/auth/failure}
  ensure
    ActionController::Base.allow_forgery_protection = false
  end
end
