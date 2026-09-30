# Base class for all notification channel adapters
# Subclasses must implement:
# - self.deliver(notification, config, state)

module Notifiers
end

class Notifiers::Base
  class NotImplementedError < StandardError; end

  def self.deliver(notification, config, state)
    raise NotImplementedError, "#{self} must implement #deliver"
  end

  protected

  # Helper to track successful delivery (stores sent_at for duration calculation on resolution)
  def self.track_delivery(state, notification)
    state.mark_sent!(
      status: notification.new_status,
      metadata: { sent_at: Time.current }
    )
  end

  # Helper to clear tracking when resolved
  def self.clear_tracking(state)
    state.mark_resolved!
  end

  # Build a basic text message for simple channels
  def self.build_text_message(notification)
    lines = []
    lines << "#{notification.icon} #{notification.title}"
    lines << ""
    lines << "Project: #{notification.details[:project]}"
    lines << "Environment: #{notification.details[:environment]}"
    lines << "Status: #{notification.details[:status]}"
    lines << "Changes: #{notification.details[:changes]}" if notification.details[:changes]
    lines << ""
    lines << "View details: #{notification.details[:url]}"

    lines.join("\n")
  end
end
