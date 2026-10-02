require "application_system_test_case"

class OidcLoginSystemTest < ApplicationSystemTestCase
  include OidcTestHelper

  def setup
    enable_oidc(button_label: "Sign in with Example SSO")
  end

  def teardown
    restore_oidc
  end

  test "SSO button signs the user in" do
    mock_oidc_login(sub: "system-sub", email: "system.user@example.com", groups: [ "drift-editors" ])

    visit login_path
    click_button "Sign in with Example SSO"

    assert_text "Logged in successfully via SSO"
    assert User.find_by(provider: "oidc", uid: "system-sub").editor?
  end

  test "SSO button is hidden when disabled" do
    Rails.application.config.oidc[:enabled] = false

    visit login_path

    assert_selector "input[name='password']"
    assert_no_button "Sign in with Example SSO"
  end
end
