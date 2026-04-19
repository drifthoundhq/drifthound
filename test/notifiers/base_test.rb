require "test_helper"
require_relative "../../app/notifiers/base"

class Notifiers::BaseTest < ActiveSupport::TestCase
  setup do
    @project = Project.create!(name: "Test Project", key: "test-project")
    @environment = @project.environments.create!(name: "Production", key: "production")
    @environment.drift_checks.create!(status: :drift, add_count: 2, change_count: 1)

    @notification = Notification.new(
      environment: @environment,
      event_type: :drift_detected,
      old_status: "ok",
      new_status: "drift"
    )

    @state = @environment.notification_states.create!(channel: "test")
    @config = { foo: "bar" }
  end

  test "raises NotImplementedError when deliver is not implemented" do
    error = assert_raises(Notifiers::Base::NotImplementedError) do
      Notifiers::Base.deliver(@notification, @config, @state)
    end

    assert_match(/must implement #deliver/, error.message)
  end

  test "track_delivery updates state with status and sent_at metadata" do
    Notifiers::Base.track_delivery(@state, @notification)

    @state.reload
    assert_nil @state.external_id
    assert_equal Environment.statuses["drift"], @state.last_notified_status
    assert_not_nil @state.metadata["sent_at"]
  end

  test "clear_tracking marks state as resolved" do
    @state.update!(external_id: "external-123", last_notified_status: Environment.statuses["drift"])

    Notifiers::Base.clear_tracking(@state)

    @state.reload
    assert_nil @state.external_id
    assert_nil @state.last_notified_status
    assert_not_nil @state.metadata["resolved_at"]
  end

  test "build_text_message creates formatted text notification" do
    text = Notifiers::Base.build_text_message(@notification)

    assert_includes text, "🟡 Drift Detected"
    assert_includes text, "Project: Test Project"
    assert_includes text, "Environment: Production"
    assert_includes text, "Status: drift"
    assert_includes text, "Changes: 2 to add, 1 to change"
    assert_includes text, "/projects/test-project/environments/production"
  end

  test "build_text_message omits changes if none present" do
    # Create environment without drift check (no changes)
    clean_env = @project.environments.create!(name: "Staging", key: "staging", status: :ok)

    ok_notification = Notification.new(
      environment: clean_env,
      event_type: :drift_resolved,
      old_status: "drift",
      new_status: "ok"
    )

    text = Notifiers::Base.build_text_message(ok_notification)

    assert_includes text, "✅ Drift Resolved"
    assert_not_includes text, "Changes:"
  end
end
