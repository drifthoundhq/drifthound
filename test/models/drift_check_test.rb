require "test_helper"

class DriftCheckTest < ActiveSupport::TestCase
  setup do
    @project = Project.create!(name: "Test Project", key: "test-project")
    @environment = @project.environments.create!(name: "Production", key: "production")
  end

  test "requires status" do
    drift_check = DriftCheck.new(environment: @environment)
    assert_not drift_check.valid?
    assert_includes drift_check.errors[:status], "can't be blank"
  end

  test "requires environment" do
    drift_check = DriftCheck.new(status: :ok)
    assert_not drift_check.valid?
    assert_includes drift_check.errors[:environment], "must exist"
  end

  test "status enum values" do
    drift_check = @environment.drift_checks.create!(status: :unknown)
    assert drift_check.unknown?

    drift_check.ok!
    assert drift_check.ok?

    drift_check.drift!
    assert drift_check.drift?

    drift_check.error!
    assert drift_check.error?
  end

  test "stores add_count, change_count, destroy_count" do
    drift_check = @environment.drift_checks.create!(
      status: :drift,
      add_count: 5,
      change_count: 3,
      destroy_count: 2
    )

    assert_equal 5, drift_check.add_count
    assert_equal 3, drift_check.change_count
    assert_equal 2, drift_check.destroy_count
  end

  test "stores raw_output" do
    raw = "Plan: 5 to add, 3 to change, 2 to destroy."
    drift_check = @environment.drift_checks.create!(status: :drift, raw_output: raw)

    assert_equal raw, drift_check.raw_output
  end

  test "updates environment status after creation" do
    assert @environment.unknown?

    @environment.drift_checks.create!(status: :ok)
    @environment.reload
    assert @environment.ok?

    @environment.drift_checks.create!(status: :drift)
    @environment.reload
    assert @environment.drift?
  end

  test "updates environment last_checked_at after creation" do
    assert_nil @environment.last_checked_at

    freeze_time do
      @environment.drift_checks.create!(status: :ok)
      @environment.reload
      assert_equal Time.current, @environment.last_checked_at
    end
  end

  test "enforces retention limit based on DRIFT_CHECK_RETENTION_DAYS" do
    # Set retention to 30 days for test
    Rails.application.config.drift_check_retention_days = 30

    # Skip retention callback while creating historical data
    DriftCheck.skip_callback(:create, :after, :enforce_retention_limit)

    # Create checks within retention period
    @environment.drift_checks.create!(status: :ok, created_at: 10.days.ago)
    @environment.drift_checks.create!(status: :ok, created_at: 20.days.ago)

    # Create checks outside retention period
    @environment.drift_checks.create!(status: :ok, created_at: 40.days.ago)
    @environment.drift_checks.create!(status: :ok, created_at: 50.days.ago)

    DriftCheck.set_callback(:create, :after, :enforce_retention_limit)

    assert_equal 4, @environment.drift_checks.count

    # Create new check - should delete checks older than 30 days
    @environment.drift_checks.create!(status: :drift)

    assert_equal 3, @environment.drift_checks.count
    # Verify oldest remaining check is within retention
    oldest_check = @environment.drift_checks.order(:created_at).first
    assert oldest_check.created_at > 30.days.ago
  end

  test "retention limit only affects same environment" do
    Rails.application.config.drift_check_retention_days = 30

    other_environment = @project.environments.create!(name: "Staging", key: "staging")

    # Skip retention callback while creating historical data
    DriftCheck.skip_callback(:create, :after, :enforce_retention_limit)

    # Create checks for both environments, some outside retention
    @environment.drift_checks.create!(status: :ok, created_at: 10.days.ago)
    @environment.drift_checks.create!(status: :ok, created_at: 40.days.ago)
    other_environment.drift_checks.create!(status: :ok, created_at: 10.days.ago)
    other_environment.drift_checks.create!(status: :ok, created_at: 40.days.ago)

    DriftCheck.set_callback(:create, :after, :enforce_retention_limit)

    # Trigger retention on first environment
    @environment.drift_checks.create!(status: :drift)

    # First environment should have old check removed
    assert_equal 2, @environment.drift_checks.count
    # Other environment should still have both checks
    assert_equal 2, other_environment.drift_checks.count
  end

  test "retention is disabled when DRIFT_CHECK_RETENTION_DAYS is 0" do
    Rails.application.config.drift_check_retention_days = 0

    # Skip retention callback while creating historical data
    DriftCheck.skip_callback(:create, :after, :enforce_retention_limit)

    # Create old checks
    @environment.drift_checks.create!(status: :ok, created_at: 100.days.ago)
    @environment.drift_checks.create!(status: :ok, created_at: 200.days.ago)
    @environment.drift_checks.create!(status: :ok, created_at: 365.days.ago)

    DriftCheck.set_callback(:create, :after, :enforce_retention_limit)

    # Create new check - should NOT delete any checks
    @environment.drift_checks.create!(status: :drift)

    assert_equal 4, @environment.drift_checks.count
  end

  test "uses default retention of 90 days" do
    # Reset to default
    Rails.application.config.drift_check_retention_days = 90

    # Skip retention callback while creating historical data
    DriftCheck.skip_callback(:create, :after, :enforce_retention_limit)

    # Create check within 90 days
    @environment.drift_checks.create!(status: :ok, created_at: 60.days.ago)
    # Create check outside 90 days
    @environment.drift_checks.create!(status: :ok, created_at: 100.days.ago)

    DriftCheck.set_callback(:create, :after, :enforce_retention_limit)

    # Trigger retention
    @environment.drift_checks.create!(status: :drift)

    assert_equal 2, @environment.drift_checks.count
    # Verify the 100-day-old check was deleted
    assert_nil @environment.drift_checks.find_by("created_at < ?", 90.days.ago)
  end

  test "delegates project to environment" do
    drift_check = @environment.drift_checks.create!(status: :ok)
    assert_equal @project, drift_check.project
  end

  test "branch is optional" do
    check = environments(:production).drift_checks.create!(status: :ok)
    assert_nil check.branch
  end

  test "branch is stripped and blank branch is stored as nil" do
    environment = environments(:production)
    assert_equal "release/1.2", environment.drift_checks.create!(status: :ok, branch: "  release/1.2 ").branch
    assert_nil environment.drift_checks.create!(status: :ok, branch: "   ").branch
  end

  test "branch is limited to 255 characters" do
    check = environments(:production).drift_checks.build(status: :ok, branch: "b" * 256)
    assert_not check.valid?
    assert_includes check.errors[:branch], "is too long (maximum is 255 characters)"
  end

  test "accepts valid git branch names" do
    environment = environments(:production)
    [ "main", "release/5.5023", "feature/foo-bar", "fix#12" ].each do |name|
      assert environment.drift_checks.build(status: :ok, branch: name).valid?, "expected #{name} to be valid"
    end
  end

  test "rejects branch names git would reject" do
    environment = environments(:production)
    [ "a..b", "bad name", "x~1", "a:b", "a^b", "a?b", "a*b", "a[b", "a\\b", "a@{b", "-main", "/main", "main/", ".main", "main.", "main.lock", "a//b", "a/.b", "a\tb" ].each do |name|
      check = environment.drift_checks.build(status: :ok, branch: name)
      assert_not check.valid?, "expected #{name.inspect} to be invalid"
      assert_includes check.errors[:branch], "is not a valid git branch name"
    end
  end
end
