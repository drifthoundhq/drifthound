class DriftCheck < ApplicationRecord
  belongs_to :environment, touch: true

  enum :status, {
    unknown: 0,
    ok: 1,
    drift: 2,
    error: 3
  }

  BRANCH_MAX_LENGTH = 255
  INVALID_BRANCH_PATTERN = %r{[\x00-\x20\x7f~^:?*\[\\]|\.\.|@\{|//|/\.|\.lock(?:/|\z)|\A[-/.]|[/.]\z}

  normalizes :branch, with: ->(branch) { branch.strip.presence }

  validates :status, presence: true
  validates :branch, length: { maximum: BRANCH_MAX_LENGTH }, allow_nil: true
  validates :branch, format: { without: INVALID_BRANCH_PATTERN, message: "is not a valid git branch name" }, allow_nil: true

  def self.valid_branch_name?(name)
    !INVALID_BRANCH_PATTERN.match?(name)
  end

  before_create :assign_execution_number
  after_create :update_environment_status
  after_create :enforce_retention_limit
  def assign_execution_number
    last_number = environment.drift_checks.maximum(:execution_number) || 0
    self.execution_number = last_number + 1
  end

  # Delegate project access for convenience
  delegate :project, to: :environment

  def change_summary
    return nil unless drift?
    return "No changes specified" if add_count.nil? && change_count.nil? && destroy_count.nil?

    parts = []
    parts << "#{add_count} to add" if add_count && add_count > 0
    parts << "#{change_count} to change" if change_count && change_count > 0
    parts << "#{destroy_count} to destroy" if destroy_count && destroy_count > 0

    parts.any? ? parts.join(", ") : "No changes"
  end

  private

  def update_environment_status
    environment.update!(status: status, last_checked_at: created_at)
  end

  def enforce_retention_limit
    retention_days = Rails.application.config.drift_check_retention_days

    # Skip retention if disabled (0 days)
    return if retention_days.zero?

    cutoff_date = retention_days.days.ago
    old_checks = environment.drift_checks.where("created_at < ?", cutoff_date)
    old_checks.destroy_all if old_checks.any?
  end
end
