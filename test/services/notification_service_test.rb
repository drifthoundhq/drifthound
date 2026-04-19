require "test_helper"

class NotificationServiceTest < ActiveSupport::TestCase
  setup do
    @project = Project.create!(name: "Test Project", key: "test-project")
    @environment = @project.environments.create!(name: "Production", key: "production", status: :ok)
  end

  test "does not notify when status hasn't changed" do
    service = NotificationService.new(@environment, "ok", "ok")

    NotificationDelivery.expects(:deliver).never

    service.call
  end

  test "does not notify on lateral move drift to drift" do
    @environment.update!(status: :drift)
    service = NotificationService.new(@environment, "drift", "drift")

    NotificationDelivery.expects(:deliver).never

    service.call
  end

  test "does not notify on lateral move error to error" do
    @environment.update!(status: :error)
    service = NotificationService.new(@environment, "error", "error")

    NotificationDelivery.expects(:deliver).never

    service.call
  end

  test "notifies when transitioning from ok to drift" do
    channel = @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#alerts" }
    )

    service = NotificationService.new(@environment, "ok", "drift")

    NotificationDelivery.expects(:deliver).once.with do |args|
      args[:notification].is_a?(Notification) &&
      args[:notification].event_type == :drift_detected &&
      args[:channel] == channel
    end

    service.call
  end

  test "notifies when transitioning from ok to error" do
    channel = @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#alerts" }
    )

    service = NotificationService.new(@environment, "ok", "error")

    NotificationDelivery.expects(:deliver).once.with do |args|
      args[:notification].is_a?(Notification) &&
      args[:notification].event_type == :error_detected &&
      args[:channel] == channel
    end

    service.call
  end

  test "notifies when transitioning from drift to ok" do
    @environment.update!(status: :drift)
    channel = @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#alerts" }
    )

    service = NotificationService.new(@environment, "drift", "ok")

    NotificationDelivery.expects(:deliver).once.with do |args|
      args[:notification].is_a?(Notification) &&
      args[:notification].event_type == :drift_resolved &&
      args[:channel] == channel
    end

    service.call
  end

  test "notifies when transitioning from error to ok" do
    @environment.update!(status: :error)
    channel = @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#alerts" }
    )

    service = NotificationService.new(@environment, "error", "ok")

    NotificationDelivery.expects(:deliver).once.with do |args|
      args[:notification].is_a?(Notification) &&
      args[:notification].event_type == :error_resolved &&
      args[:channel] == channel
    end

    service.call
  end

  test "notifies when transitioning from error to drift (posts drift_detected)" do
    @environment.update!(status: :error)
    channel = @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#alerts" }
    )

    service = NotificationService.new(@environment, "error", "drift")

    NotificationDelivery.expects(:deliver).once.with do |args|
      args[:notification].is_a?(Notification) &&
      args[:notification].event_type == :drift_detected &&
      args[:channel] == channel
    end

    service.call
  end

  test "uses environment-level channels if available" do
    # Project has one channel
    @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#project-alerts" }
    )

    # Environment has override
    env_channel = @environment.notification_channels.create!(
      channel_type: "email",
      enabled: true,
      config: { recipients: [ "env@example.com" ] }
    )

    service = NotificationService.new(@environment, "ok", "drift")

    # Should only use environment channel, not project channel
    NotificationDelivery.expects(:deliver).once.with do |args|
      args[:channel] == env_channel
    end

    service.call
  end

  test "falls back to project-level channels when environment has none" do
    project_channel = @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#project-alerts" }
    )

    service = NotificationService.new(@environment, "ok", "drift")

    NotificationDelivery.expects(:deliver).once.with do |args|
      args[:channel] == project_channel
    end

    service.call
  end

  test "only uses enabled channels" do
    @project.notification_channels.create!(
      channel_type: "slack",
      enabled: false,
      config: { channel: "#disabled" }
    )

    service = NotificationService.new(@environment, "ok", "drift")

    NotificationDelivery.expects(:deliver).never

    service.call
  end

  test "delivers to multiple channels if configured" do
    slack_channel = @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#alerts" }
    )

    email_channel = @project.notification_channels.create!(
      channel_type: "email",
      enabled: true,
      config: { recipients: [ "team@example.com" ] }
    )

    service = NotificationService.new(@environment, "ok", "drift")

    NotificationDelivery.expects(:deliver).twice

    service.call
  end

  test "does nothing when no channels are configured" do
    service = NotificationService.new(@environment, "ok", "drift")

    NotificationDelivery.expects(:deliver).never

    service.call
  end

  test "converts status symbols to strings" do
    channel = @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#alerts" }
    )

    service = NotificationService.new(@environment, :ok, :drift)

    NotificationDelivery.expects(:deliver).once

    service.call
  end

  # Tests for initial_check? behavior and notify_on_first_check configuration
  test "does not notify on initial check (unknown to drift) by default" do
    @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#alerts" }
    )

    service = NotificationService.new(@environment, "unknown", "drift")

    NotificationDelivery.expects(:deliver).never

    service.call
  end

  test "does not notify on initial check (unknown to error) by default" do
    @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#alerts" }
    )

    service = NotificationService.new(@environment, "unknown", "error")

    NotificationDelivery.expects(:deliver).never

    service.call
  end

  test "does not notify on initial check (unknown to ok) regardless of setting" do
    @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#alerts" }
    )

    service = NotificationService.new(@environment, "unknown", "ok")

    # Even with notify_on_first_check enabled, unknown -> ok should not notify
    service.stubs(:notify_on_first_check?).returns(true)

    NotificationDelivery.expects(:deliver).never

    service.call
  end

  test "notifies on initial drift when notify_on_first_check is enabled" do
    channel = @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#alerts" }
    )

    service = NotificationService.new(@environment, "unknown", "drift")
    service.stubs(:notify_on_first_check?).returns(true)

    NotificationDelivery.expects(:deliver).once.with do |args|
      args[:notification].event_type == :drift_detected &&
      args[:channel] == channel
    end

    service.call
  end

  test "notifies on initial error when notify_on_first_check is enabled" do
    channel = @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#alerts" }
    )

    service = NotificationService.new(@environment, "unknown", "error")
    service.stubs(:notify_on_first_check?).returns(true)

    NotificationDelivery.expects(:deliver).once.with do |args|
      args[:notification].event_type == :error_detected &&
      args[:channel] == channel
    end

    service.call
  end
end
