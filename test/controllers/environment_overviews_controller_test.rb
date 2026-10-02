require "test_helper"

class EnvironmentOverviewsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rails.application.config.public_mode = true

    @network = Project.create!(name: "network", key: "network")
    @database = Project.create!(name: "database", key: "database")
    @cluster = Project.create!(name: "app-cluster", key: "app-cluster")

    @network_env = @network.environments.create!(name: "Production", key: "overview-prod")
    @database_env = @database.environments.create!(name: "Production", key: "overview-prod")
    @cluster_env = @cluster.environments.create!(name: "Production", key: "overview-prod")
    @other_env = @network.environments.create!(name: "Staging", key: "overview-staging")

    @network_env.drift_checks.create!(status: :ok, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "No changes.")
    @database_env.drift_checks.create!(status: :ok, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "No changes.")
    @database_env.drift_checks.create!(status: :drift, add_count: 3, change_count: 2, destroy_count: 1, raw_output: "Plan: 3 to add, 2 to change, 1 to destroy.")
    @cluster_env.drift_checks.create!(status: :error, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "Error: failed.")
  end

  teardown do
    Rails.application.config.public_mode = false
  end

  test "shows every project for the environment key ordered by project name" do
    get environment_overview_path("overview-prod")

    assert_response :success
    assert_select "h1", "Production"
    assert_select ".environment-title code", "overview-prod"
    assert_select ".project-env-row", 3
    assert_select ".project-env-row .col-project a" do |links|
      assert_equal [ "app-cluster", "database", "network" ], links.map { |link| link.text.strip }
    end
  end

  test "links each project to its environment page" do
    get environment_overview_path("overview-prod")

    assert_select ".col-project a[href=?]", project_environment_path("database", "overview-prod"), text: "database"
  end

  test "shows status and counts from the latest check" do
    get environment_overview_path("overview-prod")

    assert_select ".project-env-row:nth-of-type(2)" do
      assert_select ".status-text--drift", "DRIFT"
      assert_select ".col-counts", /3 \/ 2 \/ 1/
    end
    assert_select ".status-text--error", "ERROR"
    assert_select ".status-text--ok", "OK"
  end

  test "shows unknown status for a project without checks" do
    empty = Project.create!(name: "storage", key: "storage")
    empty.environments.create!(name: "Production", key: "overview-prod")

    get environment_overview_path("overview-prod")

    assert_response :success
    assert_select ".project-env-row", 4
    assert_select ".status-text--unknown", "UNKNOWN"
    assert_select ".col-time", /Never/
  end

  test "does not list projects from other environments" do
    get environment_overview_path("overview-staging")

    assert_response :success
    assert_select "h1", "Staging"
    assert_select ".project-env-row", 1
  end

  test "returns 404 for unknown environment key" do
    get environment_overview_path("missing")

    assert_response :not_found
  end

  test "requires login when public mode is disabled" do
    Rails.application.config.public_mode = false

    get environment_overview_path("overview-prod")

    assert_redirected_to login_path
    assert_equal "You must be logged in to perform this action", flash[:alert]
  end

  test "logged in user can view the page when public mode is disabled" do
    Rails.application.config.public_mode = false

    post login_path, params: { email: users(:admin).email, password: "testpass1" }
    get environment_overview_path("overview-prod")

    assert_response :success
  end

  test "is accessible without login when public mode is enabled" do
    get environment_overview_path("overview-prod")

    assert_response :success
  end
end
