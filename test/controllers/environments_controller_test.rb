require "test_helper"

class EnvironmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    Rails.application.config.public_mode = false
    @project = Project.create!(name: "Plan Project", key: "plan-project")
    @env = @project.environments.create!(name: "Prod", key: "prod")
    post login_path, params: { email: users(:admin).email, password: "testpass1" }
  end

  test "history view colours the actions section of a plan and escapes its content" do
    @env.drift_checks.create!(status: :drift, add_count: 1, change_count: 1, raw_output: <<~PLAN)
      data.aws_ami.base: Reading... [id=ami-000]

      Terraform will perform the following actions:
        + resource "aws_instance" "web" {
            + tags = { "Name" = "<script>alert(1)</script>" }
          }
        ~ resource "aws_s3_bucket" "logs" {
            # (3 unchanged attributes hidden)
          }
    PLAN

    get project_environment_path(@project.key, @env.key)

    assert_response :success
    assert_select ".check-output code span.plan-symbol-add", 2
    assert_select ".check-output code span.plan-symbol-change", 1
    assert_select ".check-output code span.plan-dim", 1
    assert_select ".check-output script", 0
    assert_select ".check-history[data-controller=plan-noise] input[data-plan-noise-target=toggle]", 1
    assert_includes response.body, "&lt;script&gt;alert(1)&lt;/script&gt;"
  end

  test "history view hides the mute toggle when no check has plan output" do
    @env.drift_checks.create!(status: :ok)

    get project_environment_path(@project.key, @env.key)

    assert_response :success
    assert_select "input[data-plan-noise-target=toggle]", 0
  end

  test "history shows each check's branch and links the repository at the latest check's branch" do
    @project.update!(repository: "https://github.com/org/infra", branch: "main")
    @env.update!(directory: "envs/prod")
    @env.drift_checks.create!(status: :ok, branch: "develop")
    @env.drift_checks.create!(status: :ok, branch: "release/2.0")

    get project_environment_path(@project.key, @env.key)

    assert_response :success
    assert_select ".check-branch", text: "release/2.0", count: 1
    assert_select ".check-branch", text: "develop", count: 1
    assert_select "a[href=?]", "https://github.com/org/infra/tree/release/2.0/envs/prod"
  end

  test "repository link falls back to the project branch when the latest check has none" do
    @project.update!(repository: "https://github.com/org/infra", branch: "trunk")
    @env.update!(directory: "envs/prod")
    @env.drift_checks.create!(status: :ok, branch: "develop")
    @env.drift_checks.create!(status: :ok)

    get project_environment_path(@project.key, @env.key)

    assert_response :success
    assert_select ".check-branch", count: 1
    assert_select "a[href=?]", "https://github.com/org/infra/tree/trunk/envs/prod"
  end

  test "repository link encodes each segment of the branch and directory" do
    @project.update!(repository: "https://github.com/org/infra", branch: "main")
    @env.update!(directory: "envs/prod #1")
    @env.drift_checks.create!(status: :ok, branch: "release/fix#12")

    get project_environment_path(@project.key, @env.key)

    assert_response :success
    assert_select "a[href=?]", "https://github.com/org/infra/tree/release/fix%2312/envs/prod%20%231"
  end

  test "repository link encodes a project branch containing a question mark" do
    @project.update!(repository: "https://github.com/org/infra", branch: "what?now")
    @env.update!(directory: "envs/prod")

    get project_environment_path(@project.key, @env.key)

    assert_response :success
    assert_select "a[href=?]", "https://github.com/org/infra/tree/what%3Fnow/envs/prod"
  end
end
