require "test_helper"

class PlanOutputVisibilityTest < ActionDispatch::IntegrationTest
  PLAN_TEXT = "aws_instance.web will be updated in-place".freeze
  INITIALIZER = Rails.root.join("config/initializers/plan_output.rb").to_s

  setup do
    @original_min_role = Rails.application.config.plan_output_min_role
    @original_public_mode = Rails.application.config.public_mode
    @original_env = ENV["PLAN_OUTPUT_MIN_ROLE"]
    Rails.application.config.public_mode = false

    @project = Project.create!(name: "Plan Project", key: "plan-project")
    @environment = @project.environments.create!(name: "Production", key: "production", status: :drift)
    @environment.drift_checks.create!(status: :drift, add_count: 2, change_count: 0, destroy_count: 0, raw_output: PLAN_TEXT)
  end

  teardown do
    Rails.application.config.plan_output_min_role = @original_min_role
    Rails.application.config.public_mode = @original_public_mode
    ENV["PLAN_OUTPUT_MIN_ROLE"] = @original_env
  end

  test "viewer sees plan output with the default minimum role" do
    Rails.application.config.plan_output_min_role = "viewer"
    log_in_as(users(:viewer))

    get environment_page

    assert_response :success
    assert_includes response.body, PLAN_TEXT
    assert_not_includes response.body, "Plan output restricted"
    assert_includes response.body, "Mute"
  end

  test "anonymous public viewer sees plan output with the default minimum role" do
    Rails.application.config.plan_output_min_role = "viewer"
    Rails.application.config.public_mode = true

    get environment_page

    assert_response :success
    assert_includes response.body, PLAN_TEXT
  end

  test "viewer does not see plan output when minimum role is editor" do
    Rails.application.config.plan_output_min_role = "editor"
    log_in_as(users(:viewer))

    get environment_page

    assert_restricted_but_status_visible
  end

  test "anonymous public viewer does not see plan output when minimum role is editor" do
    Rails.application.config.plan_output_min_role = "editor"
    Rails.application.config.public_mode = true

    get environment_page

    assert_restricted_but_status_visible
  end

  test "editor and admin see plan output when minimum role is editor" do
    Rails.application.config.plan_output_min_role = "editor"

    [ users(:editor), users(:admin) ].each do |user|
      log_in_as(user)
      get environment_page

      assert_response :success
      assert_includes response.body, PLAN_TEXT, "expected #{user.role} to see plan output"
      delete logout_path
    end
  end

  test "api drift endpoint still returns raw output when plan output is restricted" do
    Rails.application.config.plan_output_min_role = "admin"
    api_token = ApiToken.create!(name: "plan-visibility-token")

    get drift_api_v1_project_environment_path(@project.key, @environment.key),
      headers: { "Authorization" => "Bearer #{api_token.token}" },
      as: :json

    assert_response :success
    assert_equal PLAN_TEXT, response.parsed_body["raw_output"]
  end

  test "minimum role defaults to viewer when PLAN_OUTPUT_MIN_ROLE is unset" do
    ENV.delete("PLAN_OUTPUT_MIN_ROLE")

    load INITIALIZER

    assert_equal "viewer", Rails.application.config.plan_output_min_role
  end

  test "PLAN_OUTPUT_MIN_ROLE is normalised" do
    ENV["PLAN_OUTPUT_MIN_ROLE"] = " Editor "

    load INITIALIZER

    assert_equal "editor", Rails.application.config.plan_output_min_role
  end

  test "an invalid PLAN_OUTPUT_MIN_ROLE stops boot" do
    ENV["PLAN_OUTPUT_MIN_ROLE"] = "owner"

    error = assert_raises(RuntimeError) { load INITIALIZER }

    assert_equal 'PLAN_OUTPUT_MIN_ROLE must be one of: viewer, editor, admin (got "owner")', error.message
  end

  private

  def environment_page
    project_environment_path(@project.key, @environment.key)
  end

  def log_in_as(user)
    post login_path, params: { email: user.email, password: "testpass1" }
  end

  def assert_restricted_but_status_visible
    assert_response :success
    assert_not_includes response.body, PLAN_TEXT
    assert_includes response.body, "Plan output restricted"
    assert_includes response.body, "2 to add"
    assert_not_includes response.body, "Mute"
  end
end
