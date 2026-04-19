class NotificationService
  def initialize(environment, old_status, new_status)
    @environment = environment
    @old_status = old_status.to_s
    @new_status = new_status.to_s
  end

  def call
    return unless should_notify?

    notification = build_notification
    deliver_to_all_channels(notification)
  end

  private

  def should_notify?
    status_changed? && !lateral_move? && !initial_check?
  end

  def status_changed?
    @old_status != @new_status
  end

  def lateral_move?
    # drift -> drift or error -> error (same severity, don't spam)
    (@old_status == "drift" && @new_status == "drift") ||
    (@old_status == "error" && @new_status == "error")
  end

  def initial_check?
    # Don't notify when transitioning from unknown (initial state)
    # unless notify_on_first_check is enabled AND there's an issue (drift/error)
    return false if notify_on_first_check? && issue_detected?

    @old_status == "unknown"
  end

  def notify_on_first_check?
    Rails.configuration.notifications[:notify_on_first_check] == true
  end

  def issue_detected?
    %w[drift error].include?(@new_status)
  end

  def build_notification
    Notification.new(
      environment: @environment,
      event_type: determine_event_type,
      old_status: @old_status,
      new_status: @new_status
    )
  end

  def determine_event_type
    # Determine event type based on status transitions
    if @new_status == "error" && @old_status != "error"
      :error_detected
    elsif @old_status == "error" && @new_status == "ok"
      :error_resolved
    elsif @old_status == "error" && @new_status == "drift"
      :drift_detected
    elsif @new_status == "drift" && @old_status != "drift"
      :drift_detected
    elsif @old_status == "drift" && @new_status == "ok"
      :drift_resolved
    else
      :unknown
    end
  end

  def deliver_to_all_channels(notification)
    enabled_channels.each do |channel|
      NotificationDelivery.deliver(
        notification: notification,
        channel: channel
      )
    end
  end

  def enabled_channels
    # Get channels configured at environment level or fallback to project level
    channels = @environment.notification_channels.enabled
    channels = @environment.project.notification_channels.enabled if channels.empty?
    channels
  end
end
