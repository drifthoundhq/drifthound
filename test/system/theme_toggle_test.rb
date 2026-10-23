require "application_system_test_case"

class ThemeToggleTest < ApplicationSystemTestCase
  def setup
    emulate_color_scheme("light")
    visit login_path
    page.execute_script("localStorage.removeItem('drifthound-theme')")
  end

  def teardown
    page.driver.browser.execute_cdp("Emulation.setEmulatedMedia", features: [])
  end

  test "toggle switches between light and dark and remembers the choice" do
    visit login_path
    assert_selector "html[data-theme='light']", visible: :all
    assert_selector ".theme-toggle[aria-pressed='false']"

    find(".theme-toggle").click
    assert_selector "html[data-theme='dark']", visible: :all
    assert_selector ".theme-toggle[aria-pressed='true']"

    visit login_path
    assert_selector "html[data-theme='dark']", visible: :all

    find(".theme-toggle").click
    assert_selector "html[data-theme='light']", visible: :all
  end

  test "follows the OS colour scheme until the user picks a theme" do
    emulate_color_scheme("dark")
    visit login_path
    assert_selector "html[data-theme='dark']", visible: :all

    find(".theme-toggle").click
    assert_selector "html[data-theme='light']", visible: :all

    visit login_path
    assert_selector "html[data-theme='light']", visible: :all
  end

  test "environment filter keeps an opaque background in dark mode after picking an environment" do
    Rails.application.config.public_mode = true
    project = Project.create!(name: "Theme Project", key: "theme-project")
    project.environments.create!(name: "Production", key: "production", status: :ok)
    project.environments.create!(name: "Staging", key: "staging", status: :drift)

    emulate_color_scheme("dark")
    page.execute_script("localStorage.removeItem('dashboardView')")
    visit root_path
    assert_selector "html[data-theme='dark']", visible: :all

    find("#env-filter").select("Staging")
    assert_selector "#env-filter[style*='--color-filter-active-bg']"

    assert_equal 255, background_alpha("#env-filter")
    assert_equal 255, background_alpha("#env-filter option")
  ensure
    Rails.application.config.public_mode = false
  end

  private

  def emulate_color_scheme(scheme)
    page.driver.browser.execute_cdp(
      "Emulation.setEmulatedMedia",
      features: [ { name: "prefers-color-scheme", value: scheme } ]
    )
  end

  def background_alpha(selector)
    page.evaluate_script(<<~JS)
      (() => {
        const ctx = document.createElement("canvas").getContext("2d");
        ctx.fillStyle = getComputedStyle(document.querySelector(#{selector.to_json})).backgroundColor;
        ctx.fillRect(0, 0, 1, 1);
        return ctx.getImageData(0, 0, 1, 1).data[3];
      })()
    JS
  end
end
