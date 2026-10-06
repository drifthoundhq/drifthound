require "test_helper"

class EnvironmentClearChecksTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @project = Project.create!(name: "Clear Project", key: "clear-project")
    @environment = @project.environments.create!(name: "Staging", key: "staging")
    @old_drift = travel_to(10.days.ago) { @environment.drift_checks.create!(status: :drift, add_count: 1) }
    @middle_ok = travel_to(5.days.ago) { @environment.drift_checks.create!(status: :ok) }
    @newest_error = travel_to(1.day.ago) { @environment.drift_checks.create!(status: :error) }
    @environment.reload
  end

  test "delete_checks_before deletes only older checks and returns the count" do
    assert_equal 2, @environment.delete_checks_before(2.days.ago)
    assert_equal [ @newest_error.id ], @environment.drift_checks.pluck(:id)
  end

  test "delete_checks_before keeps status on the newest remaining check" do
    @environment.delete_checks_before(2.days.ago)

    assert_equal "error", @environment.reload.status
    assert_in_delta @newest_error.created_at.to_f, @environment.last_checked_at.to_f, 0.001
  end

  test "deleting every check resets status to unknown and clears last_checked_at" do
    assert_equal 3, @environment.delete_checks_before(Time.current)

    @environment.reload
    assert_equal "unknown", @environment.status
    assert_nil @environment.last_checked_at
    assert_equal "unknown", @environment.last_check_status
  end

  test "deleting nothing leaves the environment untouched" do
    assert_no_changes -> { @environment.reload.updated_at } do
      assert_equal 0, @environment.delete_checks_before(30.days.ago)
    end
  end

  test "refresh_latest_check moves status back to the previous check without notifying" do
    @newest_error.destroy

    assert_no_enqueued_jobs(only: NotificationJob) do
      @environment.refresh_latest_check
    end

    assert_equal "ok", @environment.reload.status
    assert_in_delta @middle_ok.created_at.to_f, @environment.last_checked_at.to_f, 0.001
  end
end
