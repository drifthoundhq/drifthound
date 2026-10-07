require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  def teardown
    Rails.application.config.public_mode = false
  end

  test "logout lands on the login page with the logged out notice" do
    sign_in_as users(:admin)

    delete logout_path
    follow_redirect!

    assert_equal login_path, path
    assert_equal "Logged out successfully", flash[:notice]
    assert_nil flash[:alert]
  end

  test "logout in public mode lands on the dashboard with the logged out notice" do
    Rails.application.config.public_mode = true
    sign_in_as users(:admin)

    delete logout_path
    follow_redirect!

    assert_equal root_path, path
    assert_equal "Logged out successfully", flash[:notice]
  end

  private

  def sign_in_as(user)
    post login_path, params: { email: user.email, password: "testpass1" }
  end
end
