require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  setup do
    @project = Project.create!(name: "Test Project", key: "test-project")
    @environment = @project.environments.create!(name: "Production", key: "production", status: :ok)
    @drift_check = @environment.drift_checks.create!(
      status: :drift,
      add_count: 2,
      change_count: 1,
      destroy_count: 0
    )
  end

  test "initializes with required attributes" do
    notification = Notification.new(
      environment: @environment,
      event_type: :drift_detected,
      old_status: "ok",
      new_status: "drift"
    )

    assert_equal @environment, notification.environment
    assert_equal :drift_detected, notification.event_type
    assert_equal "ok", notification.old_status
    assert_equal "drift", notification.new_status
  end

  test "uses latest drift_check if not provided" do
    notification = Notification.new(
      environment: @environment,
      event_type: :drift_detected,
      old_status: "ok",
      new_status: "drift"
    )

    assert_equal @drift_check, notification.drift_check
  end

  test "can provide specific drift_check" do
    other_check = @environment.drift_checks.create!(status: :error)

    notification = Notification.new(
      environment: @environment,
      event_type: :error_detected,
      old_status: "ok",
      new_status: "error",
      drift_check: other_check
    )

    assert_equal other_check, notification.drift_check
  end

  test "title returns correct text for drift_detected" do
    notification = Notification.new(
      environment: @environment,
      event_type: :drift_detected,
      old_status: "ok",
      new_status: "drift"
    )

    assert_equal "Drift Detected", notification.title
  end

  test "title returns correct text for drift_resolved" do
    notification = Notification.new(
      environment: @environment,
      event_type: :drift_resolved,
      old_status: "drift",
      new_status: "ok"
    )

    assert_equal "Drift Resolved", notification.title
  end

  test "title returns correct text for error_detected" do
    notification = Notification.new(
      environment: @environment,
      event_type: :error_detected,
      old_status: "ok",
      new_status: "error"
    )

    assert_equal "Error Detected", notification.title
  end

  test "title returns correct text for error_resolved" do
    notification = Notification.new(
      environment: @environment,
      event_type: :error_resolved,
      old_status: "error",
      new_status: "ok"
    )

    assert_equal "Error Resolved", notification.title
  end

  test "severity returns critical for error_detected" do
    notification = Notification.new(
      environment: @environment,
      event_type: :error_detected,
      old_status: "ok",
      new_status: "error"
    )

    assert_equal :critical, notification.severity
  end

  test "severity returns warning for drift_detected" do
    notification = Notification.new(
      environment: @environment,
      event_type: :drift_detected,
      old_status: "ok",
      new_status: "drift"
    )

    assert_equal :warning, notification.severity
  end

  test "severity returns info for resolved events" do
    notification = Notification.new(
      environment: @environment,
      event_type: :drift_resolved,
      old_status: "drift",
      new_status: "ok"
    )

    assert_equal :info, notification.severity
  end

  test "icon returns correct emoji for each event type" do
    assert_equal "🟡", Notification.new(environment: @environment, event_type: :drift_detected, old_status: "ok", new_status: "drift").icon
    assert_equal "✅", Notification.new(environment: @environment, event_type: :drift_resolved, old_status: "drift", new_status: "ok").icon
    assert_equal "🔴", Notification.new(environment: @environment, event_type: :error_detected, old_status: "ok", new_status: "error").icon
    assert_equal "✅", Notification.new(environment: @environment, event_type: :error_resolved, old_status: "error", new_status: "ok").icon
  end

  test "details returns hash with project, environment, and status" do
    notification = Notification.new(
      environment: @environment,
      event_type: :drift_detected,
      old_status: "ok",
      new_status: "drift"
    )

    details = notification.details

    assert_equal "Test Project", details[:project]
    assert_equal "Production", details[:environment]
    assert_equal "drift", details[:status]
    assert_equal "2 to add, 1 to change", details[:changes]
    assert_includes details[:url], "/projects/test-project/environments/production"
  end

  test "resolution? returns true for resolved events" do
    drift_resolved = Notification.new(
      environment: @environment,
      event_type: :drift_resolved,
      old_status: "drift",
      new_status: "ok"
    )

    error_resolved = Notification.new(
      environment: @environment,
      event_type: :error_resolved,
      old_status: "error",
      new_status: "ok"
    )

    assert drift_resolved.resolution?
    assert error_resolved.resolution?
  end

  test "resolution? returns false for detected events" do
    drift_detected = Notification.new(
      environment: @environment,
      event_type: :drift_detected,
      old_status: "ok",
      new_status: "drift"
    )

    error_detected = Notification.new(
      environment: @environment,
      event_type: :error_detected,
      old_status: "ok",
      new_status: "error"
    )

    assert_not drift_detected.resolution?
    assert_not error_detected.resolution?
  end
end
