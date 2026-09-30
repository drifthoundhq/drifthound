class NotificationDelivery
  ADAPTERS = {
    "slack" => "Notifiers::Slack"
  }.freeze

  def self.deliver(notification:, channel:)
    new(notification, channel).deliver
  end

  def initialize(notification, channel)
    @notification = notification
    @channel = channel
    @adapter_class = resolve_adapter(@channel.channel_type)
  end

  def deliver
    return unless @adapter_class

    notification_state = find_or_create_state
    config = build_config

    @adapter_class.deliver(@notification, config, notification_state)
  rescue StandardError => e
    Rails.logger.error("Notification delivery failed: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    # Could send to error tracking service (Sentry, etc.)
  end

  private

  def resolve_adapter(channel_type)
    adapter_name = ADAPTERS[channel_type]
    return nil unless adapter_name

    adapter_name.constantize
  rescue NameError
    Rails.logger.warn("Notification adapter not found: #{adapter_name}")
    nil
  end

  def find_or_create_state
    NotificationState.find_or_create_by!(
      environment: @notification.environment,
      channel: @channel.channel_type
    )
  end

  def build_config
    config = @channel.config.dup

    # For Slack, always merge in the global token if not already present
    if @channel.channel_type == "slack"
      global_slack_config = Rails.application.config.notifications[:slack]
      config["token"] ||= global_slack_config[:token]
    end

    config
  end
end
