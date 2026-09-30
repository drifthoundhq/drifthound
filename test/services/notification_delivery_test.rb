require "test_helper"

class NotificationDeliveryTest < ActiveSupport::TestCase
  setup do
    @project = Project.create!(name: "Test Project", key: "test-project")
    @environment = @project.environments.create!(name: "Production", key: "production", status: :ok)
    @environment.drift_checks.create!(status: :drift, add_count: 2, change_count: 1)

    @notification = Notification.new(
      environment: @environment,
      event_type: :drift_detected,
      old_status: "ok",
      new_status: "drift"
    )

    @channel = @project.notification_channels.create!(
      channel_type: "slack",
      enabled: true,
      config: { channel: "#alerts", token: "xoxb-test" }
    )
  end

  test "delivers new notification when no previous state exists" do
    mock_adapter = mock
    mock_adapter.expects(:deliver).with(@notification, @channel.config, instance_of(NotificationState))

    NotificationDelivery.stubs(:resolve_adapter).returns(mock_adapter)

    delivery = NotificationDelivery.new(@notification, @channel)
    delivery.send(:instance_variable_set, :@adapter_class, mock_adapter)
    delivery.deliver
  end

  test "delivers new message for resolved notification (never updates in place)" do
    @environment.notification_states.create!(
      channel: "slack",
      external_id: "1234567890.123456",
      last_notified_status: Environment.statuses["drift"]
    )

    resolved_notification = Notification.new(
      environment: @environment,
      event_type: :drift_resolved,
      old_status: "drift",
      new_status: "ok"
    )

    mock_adapter = mock
    mock_adapter.expects(:deliver).with(resolved_notification, @channel.config, instance_of(NotificationState))

    delivery = NotificationDelivery.new(resolved_notification, @channel)
    delivery.send(:instance_variable_set, :@adapter_class, mock_adapter)
    delivery.deliver
  end

  test "creates notification_state if it doesn't exist" do
    assert_difference "NotificationState.count", 1 do
      mock_adapter = mock
      mock_adapter.expects(:deliver)

      delivery = NotificationDelivery.new(@notification, @channel)
      delivery.send(:instance_variable_set, :@adapter_class, mock_adapter)
      delivery.deliver
    end

    state = @environment.notification_states.last
    assert_equal "slack", state.channel
  end

  test "reuses existing notification_state" do
    @environment.notification_states.create!(channel: "slack")

    assert_no_difference "NotificationState.count" do
      mock_adapter = mock
      mock_adapter.expects(:deliver)

      delivery = NotificationDelivery.new(@notification, @channel)
      delivery.send(:instance_variable_set, :@adapter_class, mock_adapter)
      delivery.deliver
    end
  end

  test "logs error and continues when adapter raises exception" do
    mock_adapter = mock
    mock_adapter.expects(:deliver).raises(StandardError.new("API error"))

    Rails.logger.expects(:error).with(regexp_matches(/Notification delivery failed: API error/))
    Rails.logger.expects(:error).with(regexp_matches(/notification_delivery\.rb/)) # backtrace

    delivery = NotificationDelivery.new(@notification, @channel)
    delivery.send(:instance_variable_set, :@adapter_class, mock_adapter)

    # Should not raise
    delivery.deliver
    assert true # Add assertion
  end

  test "does nothing when adapter class is not found" do
    @channel.update!(channel_type: "unknown")

    # The adapter won't be found, so delivery will return early
    # Should not raise
    assert_nothing_raised do
      NotificationDelivery.deliver(notification: @notification, channel: @channel)
    end
  end

  test "resolves slack adapter" do
    delivery = NotificationDelivery.new(@notification, @channel)
    adapter_class = delivery.send(:resolve_adapter, "slack")

    assert_equal Notifiers::Slack, adapter_class
  end

  test "returns nil for unsupported adapter types" do
    @channel.update!(channel_type: "email")
    delivery = NotificationDelivery.new(@notification, @channel)
    adapter_class = delivery.send(:resolve_adapter, "email")

    # Email is not supported yet, should return nil
    assert_nil adapter_class
  end

  test "returns nil for unknown adapter type" do
    delivery = NotificationDelivery.new(@notification, @channel)
    adapter_class = delivery.send(:resolve_adapter, "unknown")

    assert_nil adapter_class
  end

  test "class method deliver creates instance and calls deliver" do
    mock_adapter = mock
    mock_adapter.expects(:deliver)

    delivery_instance = NotificationDelivery.new(@notification, @channel)
    delivery_instance.send(:instance_variable_set, :@adapter_class, mock_adapter)

    NotificationDelivery.expects(:new).with(@notification, @channel).returns(delivery_instance)

    NotificationDelivery.deliver(notification: @notification, channel: @channel)
  end

  # Tests for build_config - critical bug fix for token merging
  test "build_config merges global slack token when channel config lacks token" do
    # Channel config without token (as created by seeds)
    @channel.update!(config: { "channel" => "#test-alerts" })

    delivery = NotificationDelivery.new(@notification, @channel)
    config = delivery.send(:build_config)

    # Should have merged the global token
    assert_equal Rails.configuration.notifications[:slack][:token], config["token"]
    assert_equal "#test-alerts", config["channel"]
  end

  test "build_config preserves existing token in channel config" do
    # Channel config with its own token
    custom_token = "xoxb-custom-token"
    @channel.update!(config: { "channel" => "#test-alerts", "token" => custom_token })

    delivery = NotificationDelivery.new(@notification, @channel)
    config = delivery.send(:build_config)

    # Should keep the custom token, not replace it
    assert_equal custom_token, config["token"]
    assert_equal "#test-alerts", config["channel"]
  end

  test "build_config duplicates channel config to avoid mutation" do
    original_config = { "channel" => "#test-alerts" }
    @channel.update!(config: original_config)

    delivery = NotificationDelivery.new(@notification, @channel)
    config = delivery.send(:build_config)

    # Modify the returned config
    config["token"] = "new-token"
    config["extra"] = "value"

    # Original channel config should be unchanged
    assert_nil @channel.config["token"]
    assert_nil @channel.config["extra"]
    assert_equal "#test-alerts", @channel.config["channel"]
  end

  test "build_config only merges token for slack channels" do
    # Create a different channel type (hypothetical email)
    email_channel = @project.notification_channels.create!(
      channel_type: "email",
      enabled: true,
      config: { "address" => "test@example.com" }
    )

    delivery = NotificationDelivery.new(@notification, email_channel)
    config = delivery.send(:build_config)

    # Should not have added a token for non-slack channels
    assert_nil config["token"]
    assert_equal "test@example.com", config["address"]
  end

  test "deliver passes merged config with token to adapter" do
    # Channel without token (bug scenario)
    @channel.update!(config: { "channel" => "#alerts" })

    mock_adapter = mock
    # Verify that deliver receives config WITH the token merged in
    mock_adapter.expects(:deliver).with(
      @notification,
      has_entries("channel" => "#alerts", "token" => Rails.configuration.notifications[:slack][:token]),
      instance_of(NotificationState)
    )

    delivery = NotificationDelivery.new(@notification, @channel)
    delivery.send(:instance_variable_set, :@adapter_class, mock_adapter)
    delivery.deliver
  end

  test "deliver passes merged config with token to deliver method for resolved notifications" do
    @environment.notification_states.create!(
      channel: "slack",
      external_id: "1234567890.123456",
      last_notified_status: Environment.statuses["error"]
    )

    @channel.update!(config: { "channel" => "#alerts" })

    resolved_notification = Notification.new(
      environment: @environment,
      event_type: :error_resolved,
      old_status: "error",
      new_status: "ok"
    )

    mock_adapter = mock
    mock_adapter.expects(:deliver).with(
      resolved_notification,
      has_entries("channel" => "#alerts", "token" => Rails.configuration.notifications[:slack][:token]),
      instance_of(NotificationState)
    )

    delivery = NotificationDelivery.new(resolved_notification, @channel)
    delivery.send(:instance_variable_set, :@adapter_class, mock_adapter)
    delivery.deliver
  end
end
