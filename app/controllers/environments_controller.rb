class EnvironmentsController < ApplicationController
  before_action :set_project_and_environment
  before_action :require_login_unless_public, only: [ :show ]
  before_action :require_login, only: [ :update, :destroy ]
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def show
    authorize @environment
    @drift_checks = @environment.drift_checks.order(created_at: :desc)
    # Environment-level channel takes precedence, otherwise fall back to project-level
    @slack_channel = @environment.notification_channels.for_type("slack").enabled.first ||
                     @project.notification_channels.for_type("slack").enabled.first
  end

  def update
    authorize @environment
    @environment.update!(exclude_from_metrics: ActiveModel::Type::Boolean.new.cast(params[:exclude_from_metrics]) || false)
    notice = if @environment.exclude_from_metrics?
      "Environment '#{@environment.name}' is now excluded from dashboard metrics"
    else
      "Environment '#{@environment.name}' is now included in dashboard metrics"
    end
    redirect_to project_environment_path(@project.key, @environment.key), notice: notice
  end

  def destroy
    authorize @environment
    environment_name = @environment.name
    @environment.destroy
    redirect_to project_path(@project.key), notice: "Environment '#{environment_name}' has been deleted"
  end

  private

  def set_project_and_environment
    @project = Project.find_by!(key: params[:project_key])
    @environment = @project.environments.find_by!(key: params[:key])
  end

  def not_found
    render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
  end
end
