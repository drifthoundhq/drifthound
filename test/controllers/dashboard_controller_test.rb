require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Enable public mode for dashboard tests (these test functionality, not auth)
    Rails.application.config.public_mode = true
  end

  teardown do
    Rails.application.config.public_mode = false
  end

  test "shows dashboard" do
    get root_path
    assert_response :success
    # Check for nav brand instead of h1
    assert_select ".nav-brand", /DriftHound/
  end

  test "shows empty state when no projects exist" do
    Project.destroy_all
    get root_path
    assert_response :success
    assert_select ".empty-state"
  end

  test "shows dashboard with projects" do
    project = Project.create!(name: "Project", key: "project")
    env = project.environments.create!(name: "Production", key: "production", status: :ok)
    # Simulate a drift check so last_check_status is set
    env.drift_checks.create!(status: :ok, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "Plan: 0 to add, 0 to change, 0 to destroy.")
    get root_path
    assert_response :success
    assert_select ".project-env-row"
    assert_select ".col-project", /Project/
  end

  test "environment names link to the environment overview page" do
    Project.destroy_all
    first = Project.create!(name: "network", key: "network")
    second = Project.create!(name: "database", key: "database")
    first.environments.create!(name: "Production", key: "production")
    second.environments.create!(name: "Production", key: "production")

    get root_path

    assert_response :success
    assert_select ".project-env-row .col-environment a.env-link[href=?]", environment_overview_path("production"), text: "Production", count: 2
    assert_select ".project-env-row a.row-link[href=?]", project_environment_path("network", "production")
  end

  test "shows status counts correctly" do
    Project.destroy_all
    ok_project = Project.create!(name: "OK Project", key: "ok-project")
    drift_project = Project.create!(name: "Drift Project", key: "drift-project")
    error_project = Project.create!(name: "Error Project", key: "error-project")
    ok_env = ok_project.environments.create!(name: "Prod", key: "prod", status: :ok)
    drift_env = drift_project.environments.create!(name: "Prod", key: "prod", status: :drift)
    error_env = error_project.environments.create!(name: "Prod", key: "prod", status: :error)
    ok_env.drift_checks.create!(status: :ok, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "Plan: 0 to add, 0 to change, 0 to destroy.")
    drift_env.drift_checks.create!(status: :drift, add_count: 1, change_count: 0, destroy_count: 0, raw_output: "Plan: 1 to add, 0 to change, 0 to destroy.")
    error_env.drift_checks.create!(status: :error, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "Error: something went wrong.")

    get root_path
    assert_response :success
    assert_select ".status-badge.status-ok .count", "1"
    assert_select ".status-badge.status-drift .count", "1"
    assert_select ".status-badge.status-error .count", "1"
  end

  # ===== Chart View Tests =====

  test "dashboard renders chart cards" do
    Project.destroy_all
    project = Project.create!(name: "Chart Test Project", key: "chart-test")
    env = project.environments.create!(name: "Production", key: "production", status: :ok)
    env.drift_checks.create!(
      status: :ok,
      add_count: 1,
      change_count: 2,
      destroy_count: 0,
      duration: 5.5,
      raw_output: "Plan: 1 to add, 2 to change, 0 to destroy."
    )

    get root_path
    assert_response :success

    # Verify chart cards are rendered (12 charts)
    assert_select ".chart-card", 12

    # Verify specific chart titles
    assert_select ".chart-card h3", text: "Status Distribution"
    assert_select ".chart-card h3", text: "Stability Score"
    assert_select ".chart-card h3", text: "Drift Over Time"
    assert_select ".chart-card h3", text: "Weekly Health Trend"
    assert_select ".chart-card h3", text: "Health by Environment"
    assert_select ".chart-card h3", text: "Resource Changes"
    assert_select ".chart-card h3", text: "Drift Rate"
    assert_select ".chart-card h3", text: "Change Impact"
    assert_select ".chart-card h3", text: "Check Volume"
    assert_select ".chart-card h3", text: "Checks per Project"
    assert_select ".chart-card h3", text: "Top Drifting Projects"
    assert_select ".chart-card h3", text: "Check Duration"
  end

  test "chart cards have data attributes for filtering" do
    Project.destroy_all
    project = Project.create!(name: "Test Project", key: "test")
    env = project.environments.create!(name: "Production", key: "production", status: :ok)
    env.drift_checks.create!(status: :ok, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "OK")

    get root_path
    assert_response :success

    # Verify chart cards have data-tags attribute
    assert_select ".chart-card[data-tags]", minimum: 12

    # Verify specific tag categories exist
    assert_select ".chart-card[data-tags*='status']", minimum: 1
    assert_select ".chart-card[data-tags*='volume']", minimum: 1
    assert_select ".chart-card[data-tags*='changes']", minimum: 1
    assert_select ".chart-card[data-tags*='performance']", minimum: 1
  end

  test "chart environment filter dropdown is rendered" do
    Project.destroy_all
    project = Project.create!(name: "Test Project", key: "test")
    prod = project.environments.create!(name: "Production", key: "production", status: :ok)
    staging = project.environments.create!(name: "Staging", key: "staging", status: :drift)
    prod.drift_checks.create!(status: :ok, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "OK")
    staging.drift_checks.create!(status: :drift, add_count: 1, change_count: 0, destroy_count: 0, raw_output: "Drift")

    get root_path
    assert_response :success

    # Verify chart environment filter exists
    assert_select "#chart-env-filter"
    assert_select "#chart-env-filter option", minimum: 2 # "All" + environments
  end

  test "tag filter buttons are rendered" do
    Project.destroy_all
    project = Project.create!(name: "Test Project", key: "test")
    env = project.environments.create!(name: "Production", key: "production", status: :ok)
    env.drift_checks.create!(status: :ok, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "OK")

    get root_path
    assert_response :success

    # Verify tag filter buttons exist
    assert_select ".tag-filter-btn", minimum: 5 # All, Status, Volume, Changes, Performance
    assert_select ".tag-filter-btn[data-tag='']" # All button
    assert_select ".tag-filter-btn[data-tag='status']"
    assert_select ".tag-filter-btn[data-tag='volume']"
    assert_select ".tag-filter-btn[data-tag='changes']"
    assert_select ".tag-filter-btn[data-tag='performance']"
  end

  test "view toggle buttons are rendered" do
    get root_path
    assert_response :success

    # Verify view toggle exists
    assert_select ".view-toggle"
    assert_select "[data-view='table']"
    assert_select "[data-view='chart']"
  end

  test "chart cards have info tooltips" do
    Project.destroy_all
    project = Project.create!(name: "Test Project", key: "test")
    env = project.environments.create!(name: "Production", key: "production", status: :ok)
    env.drift_checks.create!(status: :ok, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "OK")

    get root_path
    assert_response :success

    # Verify info elements with tooltips are present
    assert_select ".chart-info[data-tooltip]", minimum: 12
  end

  test "charts section contains canvas elements for Chart.js" do
    Project.destroy_all
    project = Project.create!(name: "Test Project", key: "test")
    env = project.environments.create!(name: "Production", key: "production", status: :ok)
    env.drift_checks.create!(status: :ok, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "OK")

    get root_path
    assert_response :success

    # Verify canvas elements are present for charts
    assert_select "canvas", minimum: 10 # Most charts use canvas (stability score uses different element)
  end

  test "table filters are rendered" do
    Project.destroy_all
    project = Project.create!(name: "Test Project", key: "test")
    prod = project.environments.create!(name: "Production", key: "production", status: :ok)
    staging = project.environments.create!(name: "Staging", key: "staging", status: :drift)
    prod.drift_checks.create!(status: :ok, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "OK")
    staging.drift_checks.create!(status: :drift, add_count: 1, change_count: 0, destroy_count: 0, raw_output: "Drift")

    get root_path
    assert_response :success

    # Verify table filters exist
    assert_select "#env-filter"
    assert_select "#name-filter"
    assert_select "#clear-filters" # Note: different ID from btn
  end

  test "dashboard renders correctly with multiple environments" do
    Project.destroy_all
    project = Project.create!(name: "Multi Env Project", key: "multi-env")
    prod = project.environments.create!(name: "Production", key: "production", status: :ok)
    staging = project.environments.create!(name: "Staging", key: "staging", status: :drift)
    dev = project.environments.create!(name: "Development", key: "development", status: :error)

    prod.drift_checks.create!(status: :ok, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "OK")
    staging.drift_checks.create!(status: :drift, add_count: 1, change_count: 0, destroy_count: 0, raw_output: "Drift")
    dev.drift_checks.create!(status: :error, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "Error")

    get root_path
    assert_response :success

    # Verify all environments appear
    assert_select ".project-env-row", 3

    # Verify environment filter has all options
    assert_select "#env-filter option", minimum: 4 # "All" + 3 environments
    assert_select "#chart-env-filter option", minimum: 4
  end

  test "dashboard renders correctly with historical data" do
    Project.destroy_all
    project = Project.create!(name: "Historical Project", key: "historical")
    env = project.environments.create!(name: "Production", key: "production", status: :ok)

    # Create checks over the past 30 days
    30.times do |i|
      status = i % 3 == 0 ? :drift : :ok
      env.drift_checks.create!(
        status: status,
        add_count: i % 3,
        change_count: i % 2,
        destroy_count: 0,
        raw_output: "Check #{i}",
        created_at: i.days.ago
      )
    end

    get root_path
    assert_response :success

    # Verify charts are still rendered with historical data
    assert_select ".chart-card", 12
  end

  # ===== Exclude From Metrics Tests =====

  def chart_data(name)
    JSON.parse(css_select("[data-#{name}-data-value]").first["data-#{name}-data-value"])
  end

  test "an excluded environment stays in the table with its drift" do
    Project.destroy_all
    project = Project.create!(name: "Project", key: "project")
    prod = project.environments.create!(name: "Production", key: "production")
    sandbox = project.environments.create!(name: "Sandbox", key: "sandbox", exclude_from_metrics: true)
    prod.drift_checks.create!(status: :ok)
    sandbox.drift_checks.create!(status: :drift, add_count: 1)

    get root_path

    assert_response :success
    assert_select ".project-env-row", 2
    assert_select ".project-env-row[data-environment=Sandbox][data-status=drift] .status-text--drift", "DRIFT"
    assert_select ".status-badge.status-drift .count", "1"
    assert_select "#env-filter option[value=Sandbox]", 1
  end

  test "an excluded environment does not change the charts" do
    Project.destroy_all
    project = Project.create!(name: "Project", key: "project")
    prod = project.environments.create!(name: "Production", key: "production")
    sandbox = project.environments.create!(name: "Sandbox", key: "sandbox", exclude_from_metrics: true)
    prod.drift_checks.create!(status: :ok, duration: 10)
    sandbox.drift_checks.create!(status: :drift, add_count: 3, change_count: 2, destroy_count: 1, duration: 90)

    get root_path

    assert_response :success
    assert_equal({ "ok" => 1, "drift" => 0, "error" => 0 }, chart_data("status-chart")["all"])
    assert_equal [ "Production" ], chart_data("status-chart")["by_environment"].keys
    assert_equal [ "Production" ], chart_data("environment-health-chart")["labels"]
    assert_equal 0, chart_data("drift-chart")["all"]["drift"].sum
    assert_equal 1, chart_data("check-volume-chart")["all"].sum
    assert_equal 0, chart_data("resource-changes-chart")["all"]["adds"].sum
    assert_equal 0, chart_data("change-impact-chart")["all"]["destroys"].sum
    assert_equal 0, chart_data("drift-rate-chart")["all"].sum
    assert_equal 10.0, chart_data("duration-chart")["all"].map(&:to_f).max
    assert_equal [], chart_data("top-drifting-chart")["labels"]
    assert_equal 0, chart_data("project-chart")["all"]["drift"].sum
    assert_equal 0, chart_data("weekly-chart")["all"]["drift"].sum
  end

  test "an excluded environment does not change the stability score" do
    Project.destroy_all
    project = Project.create!(name: "Project", key: "project")
    stable = project.environments.create!(name: "Production", key: "production")
    flaky = project.environments.create!(name: "Sandbox", key: "sandbox")
    7.times { stable.drift_checks.create!(status: :ok) }
    flaky.drift_checks.create!(status: :drift, add_count: 1)

    get root_path
    score = chart_data("stability-score-chart")
    assert_equal 50.0, score["score"]
    assert_equal 2, score["total"]

    flaky.update!(exclude_from_metrics: true)

    get root_path
    score = chart_data("stability-score-chart")
    assert_equal 100.0, score["score"]
    assert_equal 1, score["total"]
    assert_not_includes score["by_environment"].keys, "Sandbox"
  end
end
