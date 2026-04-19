require "test_helper"

class NotificationStateTest < ActiveSupport::TestCase
  # Disable parallel execution to avoid fixture conflicts
  parallelize(workers: 1)

  setup do
    @environment = environments(:production)
    # Clean up any existing notification states from previous tests
    @environment.notification_states.destroy_all
  end

  test "requires channel" do
    state = NotificationState.new(environment: @environment)
    assert_not state.valid?
    assert_includes state.errors[:channel], "can't be blank"
  end

  test "requires environment" do
    state = NotificationState.new(channel: "slack")
    assert_not state.valid?
    assert_includes state.errors[:environment], "must exist"
  end

  test "channel must be unique per environment" do
    @environment.notification_states.create!(channel: "slack")
    duplicate = @environment.notification_states.new(channel: "slack")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:channel], "has already been taken"
  end

  test "same channel can exist for different environments" do
    other_environment = environments(:staging)
    # Clean up staging environment's notification states too
    other_environment.notification_states.destroy_all

    @environment.notification_states.create!(channel: "slack")
    other_state = other_environment.notification_states.new(channel: "slack")

    assert other_state.valid?
  end

  test "mark_sent! updates status and metadata" do
    state = @environment.notification_states.create!(channel: "slack")

    state.mark_sent!(
      status: "drift",
      metadata: { foo: "bar" }
    )

    state.reload
    assert_nil state.external_id
    assert_equal Environment.statuses["drift"], state.last_notified_status
    assert_equal "bar", state.metadata["foo"]
    assert_not_nil state.metadata["last_sent_at"]
  end

  test "mark_sent! merges metadata without losing existing data" do
    state = @environment.notification_states.create!(
      channel: "slack",
      metadata: { existing: "data" }
    )

    state.mark_sent!(
      status: "error",
      metadata: { new: "data" }
    )

    state.reload
    assert_equal "data", state.metadata["existing"]
    assert_equal "data", state.metadata["new"]
  end

  test "mark_resolved! clears external_id and status but keeps metadata" do
    state = @environment.notification_states.create!(
      channel: "slack",
      external_id: "1234567890.123456",
      last_notified_status: Environment.statuses["drift"],
      metadata: { last_sent_at: "2025-11-30T10:00:00Z" }
    )

    state.mark_resolved!

    state.reload
    assert_nil state.external_id
    assert_nil state.last_notified_status
    assert_not_nil state.metadata["resolved_at"]
    assert_not_nil state.metadata["last_sent_at"] # Keeps history
  end

  test "metadata defaults to empty hash" do
    state = @environment.notification_states.create!(channel: "slack")
    assert_equal({}, state.metadata)
  end
end
