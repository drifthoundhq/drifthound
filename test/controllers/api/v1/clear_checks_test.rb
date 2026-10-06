require "test_helper"

class Api::V1::ClearChecksTest < ActionDispatch::IntegrationTest
  setup do
    @write_header = { "Authorization" => "Bearer #{ApiToken.create!(name: "ci").token}" }
    @read_header = { "Authorization" => "Bearer #{ApiToken.create!(name: "dashboard", access: "read").token}" }
    @project = Project.create!(name: "my-project", key: "my-project")
    @env = @project.environments.create!(name: "Staging", key: "staging")
    @old_drift = travel_to(Time.utc(2026, 1, 5, 12)) { @env.drift_checks.create!(status: :drift, add_count: 1) }
    @new_ok = travel_to(Time.utc(2026, 1, 20, 12)) { @env.drift_checks.create!(status: :ok) }
  end

  def clear_path(project_key = @project.key, env_key = @env.key)
    api_v1_environment_checks_path(project_key, env_key)
  end

  test "deletes checks before the given date and returns the count" do
    delete clear_path, params: { before: "2026-01-10" }, headers: @write_header

    assert_response :success
    body = response.parsed_body
    assert_equal 1, body["deleted_count"]
    assert_equal "my-project", body["project_key"]
    assert_equal "staging", body["environment_key"]
    assert_equal "2026-01-10T00:00:00.000Z", body["before"]
    assert_equal [ @new_ok.id ], @env.drift_checks.pluck(:id)
    assert_equal "ok", @env.reload.status
  end

  test "accepts a timestamp" do
    delete clear_path, params: { before: "2026-01-20T13:00:00Z" }, headers: @write_header

    assert_response :success
    assert_equal 2, response.parsed_body["deleted_count"]
    assert_equal "unknown", @env.reload.status
  end

  test "returns zero when nothing is older" do
    delete clear_path, params: { before: "2025-12-01" }, headers: @write_header

    assert_response :success
    assert_equal 0, response.parsed_body["deleted_count"]
    assert_equal 2, @env.drift_checks.count
  end

  test "requires a valid before" do
    delete clear_path, headers: @write_header
    assert_response :bad_request

    delete clear_path, params: { before: "yesterday" }, headers: @write_header
    assert_response :bad_request
    assert_equal "before must be an ISO 8601 date or timestamp", response.parsed_body["error"]
    assert_equal 2, @env.drift_checks.count
  end

  test "returns not found for an unknown environment without creating it" do
    assert_no_difference -> { Environment.count } do
      delete clear_path(@project.key, "missing"), params: { before: "2026-01-10" }, headers: @write_header
    end

    assert_response :not_found
  end

  test "read-only tokens cannot clear checks" do
    delete clear_path, params: { before: "2026-01-10" }, headers: @read_header

    assert_response :forbidden
    assert_equal 2, @env.drift_checks.count
  end

  test "requires a token" do
    delete clear_path, params: { before: "2026-01-10" }

    assert_response :unauthorized
  end
end
