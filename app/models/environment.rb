class Environment < ApplicationRecord
  NAME_MAX_LENGTH = 255

  belongs_to :project
  has_many :drift_checks, dependent: :destroy
  has_many :notification_states, dependent: :destroy
  has_many :notification_channels, as: :notifiable, dependent: :destroy

  scope :included_in_metrics, -> { where(exclude_from_metrics: false) }

  # Returns the status of the most recent drift check, or 'unknown' if none
  def last_check_status
    drift_checks.order(created_at: :desc).limit(1).pluck(:status).first || "unknown"
  end

  # Deletes checks created before the given time and returns how many were deleted
  def delete_checks_before(time)
    deleted_count = drift_checks.where(created_at: ...time).destroy_all.size
    refresh_latest_check if deleted_count.positive?
    deleted_count
  end

  # Resets status and last_checked_at to the newest remaining check, without sending notifications
  def refresh_latest_check
    latest = drift_checks.order(created_at: :desc, id: :desc).first
    update_columns(
      status: latest&.status || "unknown",
      last_checked_at: latest&.created_at,
      updated_at: Time.current
    )
  end

  enum :status, {
    unknown: 0,
    ok: 1,
    drift: 2,
    error: 3
  }

  validates :name, presence: true, length: { maximum: NAME_MAX_LENGTH }
  validates :key, presence: true,
                  uniqueness: { scope: :project_id },
                  format: { with: /\A[a-z0-9_-]+\z/i, message: "only allows alphanumeric characters, dashes, and underscores" }

  before_save :sanitize_directory_path
  # Trigger notifications when status changes
  after_update :notify_status_change, if: :saved_change_to_status?

  private

  # Clean directory path by removing leading ./ or multiple ./
  # Transforms: ./path or ././path -> path
  def sanitize_directory_path
    return if directory.blank?

    self.directory = directory.gsub(%r{^(\./)+}, "")
  end

  def notify_status_change
    old_status = status_before_last_save
    new_status = status

    NotificationJob.perform_later(
      environment_id: id,
      old_status: old_status,
      new_status: new_status
    )
  end

  def self.find_or_create_by_key(project, key, name: nil)
    environment = project.environments.find_or_create_by!(key: key) do |env|
      env.name = name.presence || key.titleize
    end
    environment.update!(name: name) if name.present? && environment.persisted? && environment.name != name
    environment
  end
end
