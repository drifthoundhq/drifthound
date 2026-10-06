class DriftChecksController < ApplicationController
  before_action :set_project_and_environment
  before_action :require_login
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def destroy
    drift_check = @environment.drift_checks.find(params[:id])
    authorize drift_check
    drift_check.destroy
    @environment.refresh_latest_check
    redirect_to environment_path, notice: "Check ##{drift_check.execution_number} has been deleted"
  end

  def clear
    authorize DriftCheck, :destroy?
    before_date = parse_date(params[:before])
    return redirect_to(environment_path, alert: "Choose a valid date to clear checks before") unless before_date

    deleted_count = @environment.delete_checks_before(before_date.in_time_zone.beginning_of_day)
    redirect_to environment_path, notice: "Deleted #{deleted_count} #{"check".pluralize(deleted_count)} from before #{before_date.iso8601}"
  end

  private

  def set_project_and_environment
    @project = Project.find_by!(key: params[:project_key])
    @environment = @project.environments.find_by!(key: params[:key])
  end

  def environment_path
    project_environment_path(@project.key, @environment.key)
  end

  def parse_date(value)
    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def not_found
    render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
  end
end
