require "test_helper"

class Api::V1::DriftChecksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @api_token = ApiToken.create!(name: "test-token")
    @auth_header = { "Authorization" => "Bearer #{@api_token.token}" }
  end

  test "returns unauthorized without token" do
    post api_v1_environment_checks_path("my-project", "production"),
      params: { status: "ok" },
      as: :json

    assert_response :unauthorized
    assert_equal({ "error" => "Unauthorized" }, response.parsed_body)
  end

  test "returns unauthorized with invalid token" do
    post api_v1_environment_checks_path("my-project", "production"),
      params: { status: "ok" },
      headers: { "Authorization" => "Bearer invalid-token" },
      as: :json

    assert_response :unauthorized
  end

  test "creates drift check for new project and environment" do
    assert_difference [ "Project.count", "Environment.count", "DriftCheck.count" ], 1 do
      post api_v1_environment_checks_path("new-infra-project", "production"),
        params: { status: "ok", add_count: 0, change_count: 0, destroy_count: 0 },
        headers: @auth_header,
        as: :json
    end

    assert_response :created

    project = Project.find_by(key: "new-infra-project")
    assert_not_nil project
    assert_equal "new-infra-project", project.name

    environment = project.environments.find_by(key: "production")
    assert_not_nil environment
    assert_equal "Production", environment.name
    assert environment.ok?
  end

  test "uses environment_name as display name for new environment" do
    post api_v1_environment_checks_path("named-project", "prod-eu-west-1"),
      params: { status: "ok", environment_name: "Production EU West 1" },
      headers: @auth_header,
      as: :json

    assert_response :created
    environment = Project.find_by(key: "named-project").environments.find_by(key: "prod-eu-west-1")
    assert_equal "Production EU West 1", environment.name
  end

  test "falls back to titleized key when environment_name is absent" do
    post api_v1_environment_checks_path("named-project", "prod-eu-west-1"),
      params: { status: "ok" },
      headers: @auth_header,
      as: :json

    assert_response :created
    environment = Project.find_by(key: "named-project").environments.find_by(key: "prod-eu-west-1")
    assert_equal "Prod Eu West 1", environment.name
  end

  test "does not rename existing environment when environment_name is absent" do
    project = Project.create!(name: "Named", key: "named-project")
    environment = project.environments.create!(name: "Custom Name", key: "custom-env")

    post api_v1_environment_checks_path("named-project", "custom-env"),
      params: { status: "ok" },
      headers: @auth_header,
      as: :json

    assert_response :created
    assert_equal "Custom Name", environment.reload.name
  end

  test "renames existing environment when environment_name is given" do
    project = Project.create!(name: "Named", key: "named-project")
    environment = project.environments.create!(name: "Prod Eu West 1", key: "prod-eu-west-1")

    post api_v1_environment_checks_path("named-project", "prod-eu-west-1"),
      params: { status: "ok", environment_name: "Production EU West 1" },
      headers: @auth_header,
      as: :json

    assert_response :created
    assert_equal "Production EU West 1", environment.reload.name
  end

  test "rejects an environment_name longer than 255 characters" do
    assert_no_difference [ "Project.count", "Environment.count", "DriftCheck.count" ] do
      post api_v1_environment_checks_path("named-project", "prod-eu-west-1"),
        params: { status: "ok", environment_name: "a" * 256 },
        headers: @auth_header,
        as: :json
    end

    assert_response :unprocessable_entity
    assert_equal "environment_name is too long (maximum is 255 characters)", response.parsed_body["error"]
  end

  test "does not rename an existing environment to an overlong environment_name" do
    project = Project.create!(name: "Named", key: "named-project")
    environment = project.environments.create!(name: "Prod Eu West 1", key: "prod-eu-west-1")

    post api_v1_environment_checks_path("named-project", "prod-eu-west-1"),
      params: { status: "ok", environment_name: "a" * 256 },
      headers: @auth_header,
      as: :json

    assert_response :unprocessable_entity
    assert_equal "Prod Eu West 1", environment.reload.name
  end

  test "rejects a non-string environment_name" do
    [ [ "a", "b" ], { "name" => "Prod" }, 42 ].each do |value|
      assert_no_difference [ "Project.count", "Environment.count", "DriftCheck.count" ] do
        post api_v1_environment_checks_path("named-project", "prod-eu-west-1"),
          params: { status: "ok", environment_name: value },
          headers: @auth_header,
          as: :json
      end

      assert_response :unprocessable_entity, "expected 422 for #{value.inspect}"
      assert_equal "environment_name must be a string", response.parsed_body["error"]
    end
  end

  test "strips surrounding whitespace from environment_name" do
    post api_v1_environment_checks_path("named-project", "prod-eu-west-1"),
      params: { status: "ok", environment_name: "  Production EU West 1  " },
      headers: @auth_header,
      as: :json

    assert_response :created
    assert_equal "Production EU West 1", Project.find_by(key: "named-project").environments.find_by(key: "prod-eu-west-1").name
  end

  test "accepts an environment_name of exactly 255 characters" do
    post api_v1_environment_checks_path("named-project", "prod-eu-west-1"),
      params: { status: "ok", environment_name: "a" * 255 },
      headers: @auth_header,
      as: :json

    assert_response :created
    assert_equal "a" * 255, Project.find_by(key: "named-project").environments.find_by(key: "prod-eu-west-1").name
  end

  test "creates drift check for existing project with new environment" do
    project = Project.create!(name: "Existing", key: "existing-project")

    assert_no_difference "Project.count" do
      assert_difference [ "Environment.count", "DriftCheck.count" ], 1 do
        post api_v1_environment_checks_path("existing-project", "staging"),
          params: { status: "drift", add_count: 2, change_count: 1, destroy_count: 0 },
          headers: @auth_header,
          as: :json
      end
    end

    assert_response :created
    environment = project.environments.find_by(key: "staging")
    assert environment.drift?
  end

  test "creates drift check for existing environment" do
    project = Project.create!(name: "Existing", key: "existing-project")
    environment = project.environments.create!(name: "Production", key: "production", status: :ok)

    assert_no_difference [ "Project.count", "Environment.count" ] do
      assert_difference "DriftCheck.count", 1 do
        post api_v1_environment_checks_path("existing-project", "production"),
          params: { status: "drift", add_count: 2, change_count: 1, destroy_count: 0 },
          headers: @auth_header,
          as: :json
      end
    end

    assert_response :created
    environment.reload
    assert environment.drift?
  end

  test "returns created check details" do
    post api_v1_environment_checks_path("my-project", "production"),
      params: { status: "drift", add_count: 5, change_count: 3, destroy_count: 1 },
      headers: @auth_header,
      as: :json

    assert_response :created

    body = response.parsed_body
    assert_not_nil body["id"]
    assert_equal "my-project", body["project_key"]
    assert_equal "production", body["environment_key"]
    assert_equal "drift", body["status"]
    assert_not_nil body["created_at"]
  end

  test "accepts raw_output" do
    raw = "Plan: 2 to add, 1 to change, 0 to destroy."

    post api_v1_environment_checks_path("my-project", "production"),
      params: { status: "drift", raw_output: raw },
      headers: @auth_header,
      as: :json

    assert_response :created
    assert_equal raw, DriftCheck.last.raw_output
  end

  test "accepts all status values" do
    %w[unknown ok drift error].each do |status|
      post api_v1_environment_checks_path("status-test-#{status}", "production"),
        params: { status: status },
        headers: @auth_header,
        as: :json

      assert_response :created
    end
  end

  test "returns unprocessable entity for invalid status" do
    post api_v1_environment_checks_path("my-project", "production"),
      params: { status: "invalid" },
      headers: @auth_header,
      as: :json

    assert_response :unprocessable_entity
  end

  test "creates notification channel when provided in request" do
    # Save original config
    original_config = Rails.application.config.notifications

    # Set test global config
    Rails.application.config.notifications = {
      slack: {
        enabled: true,
        token: "xoxb-global-token",
        default_channel: "#global-channel"
      }
    }

    post api_v1_environment_checks_path("my-project", "production"),
      params: {
        status: "drift",
        notification_channel: {
          channel_type: "slack",
          enabled: true,
          config: {
            channel: "#custom-alerts"
          }
        }
      },
      headers: @auth_header,
      as: :json

    assert_response :created

    project = Project.find_by(key: "my-project")
    environment = project.environments.find_by(key: "production")
    channel = environment.notification_channels.find_by(channel_type: "slack")

    assert_not_nil channel
    assert channel.enabled?
    assert_equal "#custom-alerts", channel.config["channel"]
    assert_equal "xoxb-global-token", channel.config["token"]  # Always uses global token

    # Restore original config
    Rails.application.config.notifications = original_config
  end

  test "updates existing notification channel when provided in request" do
    # Save original config
    original_config = Rails.application.config.notifications

    # Set test global config
    Rails.application.config.notifications = {
      slack: {
        enabled: true,
        token: "xoxb-global-token",
        default_channel: "#global-channel"
      }
    }

    project = Project.create!(name: "Test", key: "test-project")
    environment = project.environments.create!(name: "Production", key: "production", status: :ok)
    environment.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { "channel" => "#old-channel", "token" => "xoxb-global-token" }
    )

    post api_v1_environment_checks_path("test-project", "production"),
      params: {
        status: "drift",
        notification_channel: {
          channel_type: "slack",
          enabled: true,
          config: {
            channel: "#new-channel"
          }
        }
      },
      headers: @auth_header,
      as: :json

    assert_response :created

    environment.reload
    channel = environment.notification_channels.find_by(channel_type: "slack")

    # Should update channel and always use global token
    assert_equal "#new-channel", channel.config["channel"]
    assert_equal "xoxb-global-token", channel.config["token"]

    # Restore original config
    Rails.application.config.notifications = original_config
  end

  test "allows partial notification config updates" do
    # Save original config
    original_config = Rails.application.config.notifications

    # Set test global config
    Rails.application.config.notifications = {
      slack: {
        enabled: true,
        token: "xoxb-global-token",
        default_channel: "#global-channel"
      }
    }

    project = Project.create!(name: "Test", key: "test-project")
    environment = project.environments.create!(name: "Production", key: "production", status: :ok)
    environment.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { "channel" => "#old-channel", "token" => "xoxb-global-token" }
    )

    # Update just the channel
    post api_v1_environment_checks_path("test-project", "production"),
      params: {
        status: "ok",
        notification_channel: {
          channel_type: "slack",
          config: {
            channel: "#updated-channel"
          }
        }
      },
      headers: @auth_header,
      as: :json

    assert_response :created

    environment.reload
    channel = environment.notification_channels.find_by(channel_type: "slack")

    assert_equal "#updated-channel", channel.config["channel"]
    assert_equal "xoxb-global-token", channel.config["token"]  # Always uses global token
    assert channel.enabled? # Should remain enabled

    # Restore original config
    Rails.application.config.notifications = original_config
  end

  test "can disable notification channel via API" do
    project = Project.create!(name: "Test", key: "test-project")
    environment = project.environments.create!(name: "Production", key: "production", status: :ok)
    environment.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { "channel" => "#alerts" }
    )

    post api_v1_environment_checks_path("test-project", "production"),
      params: {
        status: "drift",
        notification_channel: {
          channel_type: "slack",
          enabled: false
        }
      },
      headers: @auth_header,
      as: :json

    assert_response :created

    environment.reload
    channel = environment.notification_channels.find_by(channel_type: "slack")

    assert_not channel.enabled?
    assert_equal "#alerts", channel.config["channel"] # Config preserved
  end

  test "creates drift check successfully even without notification config" do
    # Ensure backwards compatibility - requests without notification_channel still work
    assert_difference "DriftCheck.count", 1 do
      post api_v1_environment_checks_path("simple-project", "production"),
        params: { status: "ok" },
        headers: @auth_header,
        as: :json
    end

    assert_response :created
  end

  test "stores repository on project when provided" do
    post api_v1_environment_checks_path("repo-test", "production"),
      params: {
        status: "ok",
        repository: "https://github.com/myorg/infrastructure"
      },
      headers: @auth_header,
      as: :json

    assert_response :created

    project = Project.find_by(key: "repo-test")
    assert_equal "https://github.com/myorg/infrastructure", project.repository
  end

  test "stores directory on environment when provided" do
    post api_v1_environment_checks_path("dir-test", "production"),
      params: {
        status: "ok",
        directory: "infra/terraform/prod"
      },
      headers: @auth_header,
      as: :json

    assert_response :created

    project = Project.find_by(key: "dir-test")
    environment = project.environments.find_by(key: "production")
    assert_equal "infra/terraform/prod", environment.directory
  end

  test "does not overwrite existing repository on project" do
    project = Project.create!(name: "Existing", key: "existing-repo", repository: "https://github.com/old/repo")

    post api_v1_environment_checks_path("existing-repo", "production"),
      params: {
        status: "ok",
        repository: "https://github.com/new/repo"
      },
      headers: @auth_header,
      as: :json

    assert_response :created

    project.reload
    # Should keep the original value, not overwrite with new one
    assert_equal "https://github.com/old/repo", project.repository
  end

  test "does not overwrite existing directory on environment" do
    project = Project.create!(name: "Existing", key: "existing-dir")
    environment = project.environments.create!(name: "Production", key: "production", directory: "old/path")

    post api_v1_environment_checks_path("existing-dir", "production"),
      params: {
        status: "ok",
        directory: "new/path"
      },
      headers: @auth_header,
      as: :json

    assert_response :created

    environment.reload
    # Should keep the original value, not overwrite with new one
    assert_equal "old/path", environment.directory
  end

  test "stores both repository and directory when provided" do
    post api_v1_environment_checks_path("full-test", "staging"),
      params: {
        status: "drift",
        add_count: 1,
        repository: "https://gitlab.com/team/infra",
        directory: "environments/staging"
      },
      headers: @auth_header,
      as: :json

    assert_response :created

    project = Project.find_by(key: "full-test")
    environment = project.environments.find_by(key: "staging")

    assert_equal "https://gitlab.com/team/infra", project.repository
    assert_equal "environments/staging", environment.directory
  end

  test "does not change repository when not provided" do
    project = Project.create!(name: "Keep Repo", key: "keep-repo", repository: "https://github.com/keep/this")

    post api_v1_environment_checks_path("keep-repo", "production"),
      params: { status: "ok" },
      headers: @auth_header,
      as: :json

    assert_response :created

    project.reload
    assert_equal "https://github.com/keep/this", project.repository
  end

  test "does not change directory when not provided" do
    project = Project.create!(name: "Keep Dir", key: "keep-dir")
    environment = project.environments.create!(name: "Production", key: "production", directory: "keep/this/path")

    post api_v1_environment_checks_path("keep-dir", "production"),
      params: { status: "ok" },
      headers: @auth_header,
      as: :json

    assert_response :created

    environment.reload
    assert_equal "keep/this/path", environment.directory
  end

  test "stores branch on project when provided" do
    post api_v1_environment_checks_path("branch-test", "production"),
      params: {
        status: "ok",
        branch: "master"
      },
      headers: @auth_header,
      as: :json

    assert_response :created

    project = Project.find_by(key: "branch-test")
    assert_equal "master", project.branch
  end

  test "does not overwrite existing branch on project" do
    project = Project.create!(name: "Existing", key: "existing-branch", branch: "develop")

    post api_v1_environment_checks_path("existing-branch", "production"),
      params: {
        status: "ok",
        branch: "master"
      },
      headers: @auth_header,
      as: :json

    assert_response :created

    project.reload
    # Should keep the original value, not overwrite with new one
    assert_equal "develop", project.branch
  end

  test "defaults branch to main when not provided" do
    post api_v1_environment_checks_path("default-branch", "production"),
      params: { status: "ok" },
      headers: @auth_header,
      as: :json

    assert_response :created

    project = Project.find_by(key: "default-branch")
    assert_equal "main", project.branch
  end

  test "falls back to global config for missing notification settings" do
    # Save original config
    original_config = Rails.application.config.notifications

    # Set test global config
    Rails.application.config.notifications = {
      slack: {
        enabled: true,
        token: "xoxb-global-token",
        default_channel: "#global-channel"
      }
    }

    # Only provide channel, should fallback to global token
    post api_v1_environment_checks_path("fallback-test", "production"),
      params: {
        status: "drift",
        notification_channel: {
          channel_type: "slack",
          enabled: true,
          config: {
            channel: "#custom-channel"
          }
        }
      },
      headers: @auth_header,
      as: :json

    assert_response :created

    project = Project.find_by(key: "fallback-test")
    environment = project.environments.find_by(key: "production")
    channel = environment.notification_channels.find_by(channel_type: "slack")

    # Should use custom channel but global token
    assert_equal "#custom-channel", channel.config["channel"]
    assert_equal "xoxb-global-token", channel.config["token"]

    # Restore original config
    Rails.application.config.notifications = original_config
  end

  test "uses all global config when no custom config provided" do
    # Save original config
    original_config = Rails.application.config.notifications

    # Set test global config
    Rails.application.config.notifications = {
      slack: {
        enabled: true,
        token: "xoxb-global-token",
        default_channel: "#global-channel"
      }
    }

    # Send empty config, should use all global defaults
    post api_v1_environment_checks_path("global-defaults", "production"),
      params: {
        status: "drift",
        notification_channel: {
          channel_type: "slack",
          enabled: true,
          config: {}
        }
      },
      headers: @auth_header,
      as: :json

    assert_response :created

    project = Project.find_by(key: "global-defaults")
    environment = project.environments.find_by(key: "production")
    channel = environment.notification_channels.find_by(channel_type: "slack")

    # Should use all global settings
    assert_equal "#global-channel", channel.config["channel"]
    assert_equal "xoxb-global-token", channel.config["token"]

    # Restore original config
    Rails.application.config.notifications = original_config
  end

  test "stores the branch on the check" do
    post api_v1_environment_checks_path("branch-project", "production"),
      params: { status: "ok", branch: "feature/network" },
      headers: @auth_header,
      as: :json

    assert_response :created
    assert_equal "feature/network", response.parsed_body["branch"]
    assert_equal "feature/network", DriftCheck.find(response.parsed_body["id"]).branch
  end

  test "each check keeps the branch it was sent with" do
    post api_v1_environment_checks_path("branch-project", "production"),
      params: { status: "ok", branch: "develop" }, headers: @auth_header, as: :json
    post api_v1_environment_checks_path("branch-project", "production"),
      params: { status: "ok", branch: "release/2.0" }, headers: @auth_header, as: :json

    environment = Project.find_by!(key: "branch-project").environments.find_by!(key: "production")
    assert_equal [ "develop", "release/2.0" ], environment.drift_checks.order(:execution_number).pluck(:branch)
    assert_equal "develop", environment.project.branch
  end

  test "check branch is nil when no branch is sent" do
    post api_v1_environment_checks_path("branch-project", "production"),
      params: { status: "ok" }, headers: @auth_header, as: :json

    assert_response :created
    assert_nil response.parsed_body["branch"]
    assert_nil DriftCheck.find(response.parsed_body["id"]).branch
  end

  test "rejects a non-string branch" do
    assert_no_difference "DriftCheck.count" do
      post api_v1_environment_checks_path("branch-project", "production"),
        params: { status: "ok", branch: { name: "main" } }, headers: @auth_header, as: :json
    end

    assert_response :unprocessable_entity
    assert_equal "branch must be a string", response.parsed_body["error"]
  end

  test "rejects a branch longer than 255 characters" do
    post api_v1_environment_checks_path("branch-project", "production"),
      params: { status: "ok", branch: "b" * 256 }, headers: @auth_header, as: :json

    assert_response :unprocessable_entity
  end
end
