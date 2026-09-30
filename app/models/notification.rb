class Notification
  attr_reader :environment, :event_type, :old_status, :new_status, :drift_check

  def initialize(environment:, event_type:, old_status:, new_status:, drift_check: nil)
    @environment = environment
    @event_type = event_type
    @old_status = old_status
    @new_status = new_status
    @drift_check = drift_check || environment.drift_checks.last
  end

  def title
    case event_type
    when :drift_detected then "Drift Detected"
    when :drift_resolved then "Drift Resolved"
    when :error_detected then "Error Detected"
    when :error_resolved then "Error Resolved"
    else "Unknown Event"
    end
  end

  def severity
    case event_type
    when :error_detected then :critical
    when :drift_detected then :warning
    when :drift_resolved, :error_resolved then :info
    else :unknown
    end
  end

  def icon
    case event_type
    when :drift_detected then "🟡"
    when :drift_resolved then "✅"
    when :error_detected then "🔴"
    when :error_resolved then "✅"
    else "ℹ️"
    end
  end

  def details
    {
      project: environment.project.name,
      environment: environment.name,
      status: new_status,
      changes: drift_check&.change_summary,
      url: environment_url
    }
  end

  def resolution?
    [ :drift_resolved, :error_resolved ].include?(event_type)
  end

  private

  def environment_url
    # This will be used by notifiers to link back to the web UI
    # For now, return a placeholder - will be filled in with actual URL helper
    "/projects/#{environment.project.key}/environments/#{environment.key}"
  end
end
