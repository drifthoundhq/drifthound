module Api
  module V1
    class DriftChecksController < BaseController
      def create
        environment_name = params[:environment_name]
        unless environment_name.nil? || environment_name.is_a?(String)
          return render json: { error: "environment_name must be a string" }, status: :unprocessable_entity
        end

        environment_name = environment_name&.strip
        if environment_name.to_s.length > Environment::NAME_MAX_LENGTH
          return render json: { error: "environment_name is too long (maximum is #{Environment::NAME_MAX_LENGTH} characters)" },
                        status: :unprocessable_entity
        end

        project = Project.find_or_create_by_key(params[:project_key])
        environment = Environment.find_or_create_by_key(project, params[:environment_key], name: environment_name)

        # Set project repository only if not already set (can be updated via GUI later)
        if params[:repository].present? && project.repository.blank?
          project.update!(repository: params[:repository])
        end

        # Set project branch only if not already set (can be updated via GUI later)
        if params[:branch].present? && project.branch == "main"
          project.update!(branch: params[:branch])
        end

        # Set environment directory only if not already set (can be updated via GUI later)
        if params[:directory].present? && environment.directory.blank?
          environment.update!(directory: params[:directory])
        end

        # Update or create notification channel if configuration is provided
        if params[:notification_channel].present?
          update_notification_channel(environment)
        end

        drift_check = environment.drift_checks.create!(drift_check_params)

        render json: {
          id: drift_check.id,
          project_key: project.key,
          environment_key: environment.key,
          status: drift_check.status,
          created_at: drift_check.created_at
        }, status: :created
      end

      # DELETE /api/v1/projects/:project_key/environments/:environment_key/checks?before=<ISO 8601>
      def clear
        before_time = parse_before
        return render json: { error: "before must be an ISO 8601 date or timestamp" }, status: :bad_request unless before_time

        project = Project.find_by!(key: params[:project_key])
        environment = project.environments.find_by!(key: params[:environment_key])
        deleted_count = environment.delete_checks_before(before_time)

        render json: {
          project_key: project.key,
          environment_key: environment.key,
          before: before_time,
          deleted_count: deleted_count
        }
      end

      private

      def parse_before
        return nil if params[:before].blank? || !params[:before].is_a?(String)

        ActiveSupport::TimeZone["UTC"].iso8601(params[:before])
      rescue ArgumentError
        nil
      end

      def drift_check_params
        params.permit(:status, :add_count, :change_count, :destroy_count, :duration, :raw_output)
      end

      def update_notification_channel(environment)
        channel_params = params.require(:notification_channel)
                               .permit(:channel_type, :enabled, config: [ :channel ])

        # Find or initialize the notification channel
        channel = environment.notification_channels
                             .find_or_initialize_by(channel_type: channel_params[:channel_type])

        # Update enabled status if provided
        channel.enabled = channel_params[:enabled] if channel_params.key?(:enabled)

        # Update config
        channel.config ||= {}

        # For Slack, always use global token
        if channel_params[:channel_type] == "slack"
          global_slack_config = Rails.application.config.notifications[:slack]

          # Set channel from params or use global default
          if channel_params[:config].present? && channel_params[:config][:channel].present?
            channel.config["channel"] = channel_params[:config][:channel]
          else
            channel.config["channel"] ||= global_slack_config[:default_channel]
          end

          # Always use global token
          channel.config["token"] = global_slack_config[:token]
        end

        channel.save!
      end
    end
  end
end
