require "test_helper"

class Api::V1::EnvironmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @api_token = ApiToken.create!(name: "test-token")
    @auth_header = { "Authorization" => "Bearer #{@api_token.token}" }
    @project = Project.create!(name: "Test Project", key: "test-project", repository: "https://github.com/org/repo", branch: "main")
  end

  # Authentication tests
  test "returns unauthorized without token for index" do
    get api_v1_project_environments_path(@project.key), as: :json

    assert_response :unauthorized
  end

  test "returns unauthorized without token for show" do
    env = @project.environments.create!(name: "Prod", key: "prod", status: :ok)

    get api_v1_project_environment_path(@project.key, env.key), as: :json

    assert_response :unauthorized
  end

  test "returns unauthorized without token for drift" do
    env = @project.environments.create!(name: "Prod", key: "prod", status: :ok)

    get drift_api_v1_project_environment_path(@project.key, env.key), as: :json

    assert_response :unauthorized
  end

  # Index action tests
  test "returns empty array when no environments exist" do
    get api_v1_project_environments_path(@project.key),
      headers: @auth_header,
      as: :json

    assert_response :success
    assert_equal [], response.parsed_body
  end

  test "returns all environments for project" do
    @project.environments.create!(name: "Production", key: "production", status: :ok)
    @project.environments.create!(name: "Staging", key: "staging", status: :drift)

    get api_v1_project_environments_path(@project.key),
      headers: @auth_header,
      as: :json

    assert_response :success
    body = response.parsed_body

    assert_equal 2, body.length
  end

  test "returns environment with correct attributes" do
    env = @project.environments.create!(
      name: "Production",
      key: "production",
      status: :drift,
      directory: "terraform/prod",
      last_checked_at: Time.current
    )
    env.drift_checks.create!(status: :drift, add_count: 2, change_count: 1, destroy_count: 0)

    get api_v1_project_environments_path(@project.key),
      headers: @auth_header,
      as: :json

    assert_response :success
    body = response.parsed_body.first

    assert_equal "production", body["key"]
    assert_equal "Production", body["name"]
    assert_equal "drift", body["status"]
    assert_equal "terraform/prod", body["directory"]
    assert_not_nil body["last_checked_at"]
    assert_not_nil body["last_drift_check"]
    assert_equal "drift", body["last_drift_check"]["status"]
    assert_equal 2, body["last_drift_check"]["add_count"]
  end

  test "filters environments by status" do
    @project.environments.create!(name: "Production", key: "production", status: :drift)
    @project.environments.create!(name: "Staging", key: "staging", status: :ok)
    @project.environments.create!(name: "Dev", key: "dev", status: :drift)

    get api_v1_project_environments_path(@project.key),
      params: { status: "drift" },
      headers: @auth_header,
      as: :json

    assert_response :success
    body = response.parsed_body

    assert_equal 2, body.length
    assert body.all? { |e| e["status"] == "drift" }
  end

  test "returns not found for non-existent project" do
    get api_v1_project_environments_path("non-existent"),
      headers: @auth_header,
      as: :json

    assert_response :not_found
  end

  # Show action tests
  test "returns environment by key" do
    env = @project.environments.create!(
      name: "Production",
      key: "production",
      status: :drift,
      directory: "terraform/prod"
    )

    get api_v1_project_environment_path(@project.key, "production"),
      headers: @auth_header,
      as: :json

    assert_response :success
    body = response.parsed_body

    assert_equal "production", body["key"]
    assert_equal "Production", body["name"]
    assert_equal "drift", body["status"]
    assert_equal "terraform/prod", body["directory"]
  end

  test "returns environment with project info in show response" do
    @project.environments.create!(name: "Prod", key: "prod", status: :ok)

    get api_v1_project_environment_path(@project.key, "prod"),
      headers: @auth_header,
      as: :json

    assert_response :success
    body = response.parsed_body

    assert_not_nil body["project"]
    assert_equal "test-project", body["project"]["key"]
    assert_equal "Test Project", body["project"]["name"]
    assert_equal "https://github.com/org/repo", body["project"]["repository"]
    assert_equal "main", body["project"]["branch"]
  end

  test "returns last drift check summary in show response" do
    env = @project.environments.create!(name: "Prod", key: "prod", status: :drift)
    env.drift_checks.create!(status: :ok, add_count: 0, change_count: 0, destroy_count: 0)
    latest = env.drift_checks.create!(status: :drift, add_count: 5, change_count: 3, destroy_count: 1, duration: 120)

    get api_v1_project_environment_path(@project.key, "prod"),
      headers: @auth_header,
      as: :json

    assert_response :success
    body = response.parsed_body

    assert_not_nil body["last_drift_check"]
    assert_equal latest.id, body["last_drift_check"]["id"]
    assert_equal "drift", body["last_drift_check"]["status"]
    assert_equal 5, body["last_drift_check"]["add_count"]
    assert_equal 3, body["last_drift_check"]["change_count"]
    assert_equal 1, body["last_drift_check"]["destroy_count"]
    assert_equal 120, body["last_drift_check"]["duration"]
    assert_equal "5 to add, 3 to change, 1 to destroy", body["last_drift_check"]["change_summary"]
  end

  test "returns not found for non-existent environment" do
    get api_v1_project_environment_path(@project.key, "non-existent"),
      headers: @auth_header,
      as: :json

    assert_response :not_found
  end

  # Drift action tests
  test "returns latest drift check with raw_output" do
    env = @project.environments.create!(name: "Prod", key: "prod", status: :drift)
    raw_output = <<~PLAN
      Terraform will perform the following actions:

        # aws_instance.example will be updated in-place
        ~ resource "aws_instance" "example" {
            ~ instance_type = "t2.micro" -> "t2.small"
          }

      Plan: 0 to add, 1 to change, 0 to destroy.
    PLAN

    env.drift_checks.create!(status: :ok, raw_output: "No changes")
    latest = env.drift_checks.create!(
      status: :drift,
      add_count: 0,
      change_count: 1,
      destroy_count: 0,
      duration: 45,
      raw_output: raw_output
    )

    get drift_api_v1_project_environment_path(@project.key, "prod"),
      headers: @auth_header,
      as: :json

    assert_response :success
    body = response.parsed_body

    assert_equal latest.id, body["id"]
    assert_equal "drift", body["status"]
    assert_equal 0, body["add_count"]
    assert_equal 1, body["change_count"]
    assert_equal 0, body["destroy_count"]
    assert_equal 45, body["duration"]
    assert_equal raw_output, body["raw_output"]
    assert_equal "prod", body["environment_key"]
    assert_equal "test-project", body["project_key"]
    assert_not_nil body["created_at"]
    assert_not_nil body["execution_number"]
  end

  test "returns not found when no drift checks exist" do
    @project.environments.create!(name: "Prod", key: "prod", status: :unknown)

    get drift_api_v1_project_environment_path(@project.key, "prod"),
      headers: @auth_header,
      as: :json

    assert_response :not_found
    assert_equal({ "error" => "No drift checks found for this environment" }, response.parsed_body)
  end

  test "returns not found for non-existent environment in drift action" do
    get drift_api_v1_project_environment_path(@project.key, "non-existent"),
      headers: @auth_header,
      as: :json

    assert_response :not_found
    assert_equal({ "error" => "Not found" }, response.parsed_body)
  end

  test "returns change_summary for drift status" do
    env = @project.environments.create!(name: "Prod", key: "prod", status: :drift)
    env.drift_checks.create!(
      status: :drift,
      add_count: 2,
      change_count: 3,
      destroy_count: 1,
      raw_output: "Plan output"
    )

    get drift_api_v1_project_environment_path(@project.key, "prod"),
      headers: @auth_header,
      as: :json

    assert_response :success
    assert_equal "2 to add, 3 to change, 1 to destroy", response.parsed_body["change_summary"]
  end

  test "returns nil change_summary for ok status" do
    env = @project.environments.create!(name: "Prod", key: "prod", status: :ok)
    env.drift_checks.create!(
      status: :ok,
      add_count: 0,
      change_count: 0,
      destroy_count: 0,
      raw_output: "No changes"
    )

    get drift_api_v1_project_environment_path(@project.key, "prod"),
      headers: @auth_header,
      as: :json

    assert_response :success
    assert_nil response.parsed_body["change_summary"]
  end

  # Edge cases
  test "handles environment with nil directory" do
    @project.environments.create!(name: "Prod", key: "prod", status: :ok, directory: nil)

    get api_v1_project_environment_path(@project.key, "prod"),
      headers: @auth_header,
      as: :json

    assert_response :success
    assert_nil response.parsed_body["directory"]
  end

  test "handles environment with no drift checks" do
    @project.environments.create!(name: "Prod", key: "prod", status: :unknown)

    get api_v1_project_environment_path(@project.key, "prod"),
      headers: @auth_header,
      as: :json

    assert_response :success
    assert_nil response.parsed_body["last_drift_check"]
  end
end
