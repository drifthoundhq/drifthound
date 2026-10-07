require "application_system_test_case"

class FlashPlacementTest < ApplicationSystemTestCase
  def teardown
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  [ 1400, 800 ].each do |width|
    test "flash sits below the nav bar at #{width}px wide" do
      page.driver.browser.manage.window.resize_to(width, 900)
      log_in_as users(:admin)
      assert_selector ".flash-notice", text: "Logged in successfully"

      flash_top = page.evaluate_script("document.querySelector('.flash-messages').getBoundingClientRect().top")
      nav_bottom = page.evaluate_script("document.querySelector('.top-nav').getBoundingClientRect().bottom")

      assert_operator flash_top, :>=, nav_bottom, "flash overlaps the nav bar"
    end
  end

  private

  def log_in_as(user)
    visit login_path
    fill_in "email", with: user.email
    fill_in "password", with: "testpass1"
    find("input[type=submit], button[type=submit]").click
  end
end
