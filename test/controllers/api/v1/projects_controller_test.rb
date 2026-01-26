require "test_helper"

class Api::V1::ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Clean up any existing data from fixtures to ensure test isolation
    DriftCheck.destroy_all
    Environment.destroy_all
    Project.destroy_all

    @api_token = ApiToken.create!(name: "test-token")
    @auth_header = { "Authorization" => "Bearer #{@api_token.token}" }
  end

  # Authentication tests
  test "returns unauthorized without token" do
    get api_v1_projects_path, as: :json

    assert_response :unauthorized
    assert_equal({ "error" => "Unauthorized" }, response.parsed_body)
  end

  test "returns unauthorized with invalid token" do
    get api_v1_projects_path,
      headers: { "Authorization" => "Bearer invalid-token" },
      as: :json

    assert_response :unauthorized
  end

  # Index action tests
  test "returns empty array when no projects exist" do
    get api_v1_projects_path,
      headers: @auth_header,
      as: :json

    assert_response :success
    assert_equal [], response.parsed_body
  end

  test "returns all projects" do
    project1 = Project.create!(name: "Project Alpha", key: "project-alpha")
    project2 = Project.create!(name: "Project Beta", key: "project-beta")

    get api_v1_projects_path,
      headers: @auth_header,
      as: :json

    assert_response :success
    body = response.parsed_body

    assert_equal 2, body.length
    assert_equal "project-alpha", body[0]["key"]
    assert_equal "project-beta", body[1]["key"]
  end

  test "returns project with correct attributes" do
    project = Project.create!(
      name: "Infrastructure",
      key: "infra",
      repository: "https://github.com/org/infra",
      branch: "main"
    )
    project.environments.create!(name: "Production", key: "production", status: :drift)
    project.environments.create!(name: "Staging", key: "staging", status: :ok)

    get api_v1_projects_path,
      headers: @auth_header,
      as: :json

    assert_response :success
    body = response.parsed_body.first

    assert_equal "infra", body["key"]
    assert_equal "Infrastructure", body["name"]
    assert_equal "https://github.com/org/infra", body["repository"]
    assert_equal "main", body["branch"]
    assert_equal "drift", body["aggregated_status"]
    assert_equal 2, body["environment_count"]
    assert_equal 1, body["drift_environment_count"]
  end

  test "filters projects with drift when with_drift=true" do
    project_with_drift = Project.create!(name: "Drifting", key: "drifting")
    project_with_drift.environments.create!(name: "Prod", key: "prod", status: :drift)

    project_ok = Project.create!(name: "OK Project", key: "ok-project")
    project_ok.environments.create!(name: "Prod", key: "prod", status: :ok)

    project_no_envs = Project.create!(name: "Empty", key: "empty")

    get api_v1_projects_path,
      params: { with_drift: "true" },
      headers: @auth_header,
      as: :json

    assert_response :success
    body = response.parsed_body

    assert_equal 1, body.length
    assert_equal "drifting", body[0]["key"]
  end

  test "returns all projects when with_drift is not true" do
    project1 = Project.create!(name: "Project 1", key: "project-1")
    project1.environments.create!(name: "Prod", key: "prod", status: :drift)

    project2 = Project.create!(name: "Project 2", key: "project-2")
    project2.environments.create!(name: "Prod", key: "prod", status: :ok)

    get api_v1_projects_path,
      params: { with_drift: "false" },
      headers: @auth_header,
      as: :json

    assert_response :success
    assert_equal 2, response.parsed_body.length
  end

  test "does not include environments in index response" do
    project = Project.create!(name: "Test", key: "test")
    project.environments.create!(name: "Prod", key: "prod", status: :ok)

    get api_v1_projects_path,
      headers: @auth_header,
      as: :json

    assert_response :success
    body = response.parsed_body.first

    assert_nil body["environments"]
  end

  # Show action tests
  test "returns project by key" do
    project = Project.create!(
      name: "My Project",
      key: "my-project",
      repository: "https://github.com/org/repo",
      branch: "develop"
    )

    get api_v1_project_path("my-project"),
      headers: @auth_header,
      as: :json

    assert_response :success
    body = response.parsed_body

    assert_equal "my-project", body["key"]
    assert_equal "My Project", body["name"]
    assert_equal "https://github.com/org/repo", body["repository"]
    assert_equal "develop", body["branch"]
  end

  test "returns project with environments in show response" do
    project = Project.create!(name: "Test", key: "test")
    project.environments.create!(name: "Production", key: "production", status: :drift, directory: "envs/prod")
    project.environments.create!(name: "Staging", key: "staging", status: :ok, directory: "envs/staging")

    get api_v1_project_path("test"),
      headers: @auth_header,
      as: :json

    assert_response :success
    body = response.parsed_body

    assert_not_nil body["environments"]
    assert_equal 2, body["environments"].length

    prod_env = body["environments"].find { |e| e["key"] == "production" }
    assert_equal "Production", prod_env["name"]
    assert_equal "drift", prod_env["status"]
    assert_equal "envs/prod", prod_env["directory"]
  end

  test "returns not found for non-existent project" do
    get api_v1_project_path("non-existent"),
      headers: @auth_header,
      as: :json

    assert_response :not_found
    assert_equal({ "error" => "Not found" }, response.parsed_body)
  end

  test "returns aggregated status correctly" do
    # Test error takes precedence
    project = Project.create!(name: "Test", key: "test-error")
    project.environments.create!(name: "Prod", key: "prod", status: :ok)
    project.environments.create!(name: "Staging", key: "staging", status: :error)

    get api_v1_project_path("test-error"),
      headers: @auth_header,
      as: :json

    assert_response :success
    assert_equal "error", response.parsed_body["aggregated_status"]

    # Test drift takes precedence over ok
    project2 = Project.create!(name: "Test 2", key: "test-drift")
    project2.environments.create!(name: "Prod", key: "prod", status: :ok)
    project2.environments.create!(name: "Staging", key: "staging", status: :drift)

    get api_v1_project_path("test-drift"),
      headers: @auth_header,
      as: :json

    assert_response :success
    assert_equal "drift", response.parsed_body["aggregated_status"]

    # Test all ok
    project3 = Project.create!(name: "Test 3", key: "test-ok")
    project3.environments.create!(name: "Prod", key: "prod", status: :ok)
    project3.environments.create!(name: "Staging", key: "staging", status: :ok)

    get api_v1_project_path("test-ok"),
      headers: @auth_header,
      as: :json

    assert_response :success
    assert_equal "ok", response.parsed_body["aggregated_status"]
  end

  test "returns last_checked_at from most recent environment check" do
    project = Project.create!(name: "Test", key: "test")
    env1 = project.environments.create!(name: "Prod", key: "prod", status: :ok, last_checked_at: 2.hours.ago)
    env2 = project.environments.create!(name: "Staging", key: "staging", status: :ok, last_checked_at: 1.hour.ago)

    get api_v1_project_path("test"),
      headers: @auth_header,
      as: :json

    assert_response :success

    # Should return the most recent check time
    last_checked = Time.parse(response.parsed_body["last_checked_at"])
    assert_in_delta env2.last_checked_at.to_i, last_checked.to_i, 1
  end
end
