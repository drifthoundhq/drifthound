require "test_helper"

class Api::V1::ChecksControllerTest < ActionDispatch::IntegrationTest
  setup do
    DriftCheck.delete_all
    @api_token = ApiToken.create!(name: "test-token")
    @auth_header = { "Authorization" => "Bearer #{@api_token.token}" }
    @project = Project.create!(name: "History Project", key: "history-project")
    @env = @project.environments.create!(name: "Prod", key: "prod")
    @other_project = Project.create!(name: "Other Project", key: "other-project")
    @other_env = @other_project.environments.create!(name: "Prod", key: "prod")
  end

  def create_check(environment, at:, **attrs)
    travel_to(at) do
      environment.drift_checks.create!({ status: :ok, raw_output: "secret plan output" }.merge(attrs))
    end
  end

  def environment_checks(params = {})
    get api_v1_environment_checks_path(@project.key, @env.key), params: params, headers: @auth_header
  end

  test "environment checks return unauthorized without token" do
    get api_v1_environment_checks_path(@project.key, @env.key)

    assert_response :unauthorized
  end

  test "all checks return unauthorized with invalid token" do
    get api_v1_checks_path, headers: { "Authorization" => "Bearer wrong" }

    assert_response :unauthorized
  end

  test "environment checks are newest first with expected fields and no raw output" do
    older = create_check(@env, at: 3.days.ago, status: :ok, duration: 12)
    newer = create_check(@env, at: 1.day.ago, status: :drift, add_count: 2, change_count: 1, destroy_count: 0)
    create_check(@other_env, at: 2.days.ago)

    environment_checks

    assert_response :success
    checks = response.parsed_body["checks"]
    assert_equal [ newer.id, older.id ], checks.map { |c| c["id"] }

    first = checks.first
    assert_equal "history-project", first["project_key"]
    assert_equal "prod", first["environment_key"]
    assert_equal "drift", first["status"]
    assert_equal 2, first["add_count"]
    assert_equal 1, first["change_count"]
    assert_equal 0, first["destroy_count"]
    assert_equal "2 to add, 1 to change", first["change_summary"]
    assert_equal 12, checks.last["duration"]
    assert_not_nil first["created_at"]
    checks.each { |c| assert_not c.key?("raw_output") }
    assert_not_includes response.body, "secret plan output"
  end

  test "since and until filter by created_at" do
    create_check(@env, at: Time.utc(2026, 1, 1, 12))
    middle = create_check(@env, at: Time.utc(2026, 1, 5, 12))
    create_check(@env, at: Time.utc(2026, 1, 10, 12))

    travel_to(Time.utc(2026, 1, 11)) do
      environment_checks(since: "2026-01-02T00:00:00Z", until: "2026-01-10")
    end

    assert_response :success
    assert_equal [ middle.id ], response.parsed_body["checks"].map { |c| c["id"] }
  end

  test "timestamps without an offset are read as UTC whatever the server time zone" do
    check = create_check(@env, at: Time.utc(2026, 1, 2, 2))
    original_tz = ENV["TZ"]
    ENV["TZ"] = "America/New_York"

    travel_to(Time.utc(2026, 1, 3)) do
      environment_checks(since: "2026-01-02T00:00:00", until: "2026-01-02T03:00:00")
    end

    assert_response :success
    assert_equal [ check.id ], response.parsed_body["checks"].map { |c| c["id"] }
  ensure
    ENV["TZ"] = original_tz
  end

  test "project and environment filters must be single keys" do
    [
      { project: [ @project.key, @other_project.key ] },
      { environment: [ "prod", "staging" ] },
      { project: { key: @project.key } }
    ].each do |params|
      get api_v1_checks_path, params: params, headers: @auth_header

      assert_response :bad_request, "expected 400 for #{params.inspect}"
      assert response.parsed_body["error"].present?
    end
  end

  test "limit and cursor paginate without gaps or duplicates" do
    ids = 5.times.map { |i| create_check(@env, at: (10 - i).hours.ago).id }.reverse

    environment_checks(limit: 2)
    page1 = response.parsed_body
    assert_equal ids[0, 2], page1["checks"].map { |c| c["id"] }
    assert_equal 2, page1["pagination"]["limit"]
    assert page1["pagination"]["has_more"]

    environment_checks(limit: 2, cursor: page1["pagination"]["next_cursor"])
    page2 = response.parsed_body
    assert_equal ids[2, 2], page2["checks"].map { |c| c["id"] }

    environment_checks(limit: 2, cursor: page2["pagination"]["next_cursor"])
    page3 = response.parsed_body
    assert_equal ids[4, 1], page3["checks"].map { |c| c["id"] }
    assert_not page3["pagination"]["has_more"]
    assert_nil page3["pagination"]["next_cursor"]
  end

  test "cursor breaks ties on identical timestamps by id" do
    at = 1.hour.ago
    ids = 3.times.map { create_check(@env, at: at).id }.sort.reverse

    environment_checks(limit: 2)
    first_page = response.parsed_body
    environment_checks(limit: 2, cursor: first_page["pagination"]["next_cursor"])

    assert_equal ids, first_page["checks"].map { |c| c["id"] } + response.parsed_body["checks"].map { |c| c["id"] }
  end

  test "default limit is 50" do
    55.times { |i| create_check(@env, at: (i + 1).minutes.ago) }

    environment_checks

    body = response.parsed_body
    assert_equal 50, body["checks"].size
    assert_equal 50, body["pagination"]["limit"]
    assert body["pagination"]["has_more"]
  end

  test "invalid parameters return bad request" do
    [
      { limit: "0" },
      { limit: "501" },
      { limit: "abc" },
      { since: "yesterday" },
      { until: "2026-13-45" },
      { cursor: "not-a-cursor" }
    ].each do |params|
      environment_checks(params)

      assert_response :bad_request, "expected 400 for #{params.inspect}"
      assert response.parsed_body["error"].present?
    end
  end

  test "unknown project or environment returns not found" do
    get api_v1_environment_checks_path("missing", @env.key), headers: @auth_header
    assert_response :not_found

    get api_v1_environment_checks_path(@project.key, "missing"), headers: @auth_header
    assert_response :not_found

    get api_v1_checks_path, params: { project: "missing" }, headers: @auth_header
    assert_response :not_found

    get api_v1_checks_path, params: { environment: "missing" }, headers: @auth_header
    assert_response :not_found
  end

  test "all checks span projects newest first" do
    a = create_check(@env, at: 2.hours.ago)
    b = create_check(@other_env, at: 1.hour.ago)

    get api_v1_checks_path, headers: @auth_header

    assert_response :success
    checks = response.parsed_body["checks"]
    assert_equal [ b.id, a.id ], checks.map { |c| c["id"] }
    assert_equal [ "other-project", "history-project" ], checks.map { |c| c["project_key"] }
  end

  test "all checks filter by project and environment" do
    staging = @project.environments.create!(name: "Staging", key: "staging")
    prod_check = create_check(@env, at: 3.hours.ago)
    staging_check = create_check(staging, at: 2.hours.ago)
    other_check = create_check(@other_env, at: 1.hour.ago)

    get api_v1_checks_path, params: { project: @project.key }, headers: @auth_header
    assert_equal [ staging_check.id, prod_check.id ], response.parsed_body["checks"].map { |c| c["id"] }

    get api_v1_checks_path, params: { environment: "prod" }, headers: @auth_header
    assert_equal [ other_check.id, prod_check.id ], response.parsed_body["checks"].map { |c| c["id"] }

    get api_v1_checks_path, params: { project: @project.key, environment: "prod" }, headers: @auth_header
    assert_equal [ prod_check.id ], response.parsed_body["checks"].map { |c| c["id"] }
  end

  test "all checks does not issue a query per check" do
    3.times { |i| create_check(@env, at: (i + 1).hours.ago) }
    3.times { |i| create_check(@other_env, at: (i + 1).hours.ago) }

    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get api_v1_checks_path, headers: @auth_header
    end

    assert_response :success
    assert_equal 6, response.parsed_body["checks"].size
    assert_equal 1, queries.count { |q| q.include?("drift_checks") }
    assert_equal 1, queries.count { |q| q.include?(%("environments")) && !q.include?("drift_checks") }
    assert_equal 1, queries.count { |q| q.include?(%("projects")) }
  end
end
