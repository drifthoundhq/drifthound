class NotificationState < ApplicationRecord
  belongs_to :environment

  validates :channel, presence: true, uniqueness: { scope: :environment_id }

  # Track that we sent a notification
  def mark_sent!(status:, metadata: {}, external_id: nil)
    update!(
      external_id: external_id,
      last_notified_status: Environment.statuses[status],
      metadata: self.metadata.merge(metadata).merge(last_sent_at: Time.current.iso8601)
    )
  end

  # Clear tracking when resolved
  def mark_resolved!
    update!(
      external_id: nil,
      last_notified_status: nil,
      metadata: self.metadata.merge(resolved_at: Time.current.iso8601)
    )
  end
end
