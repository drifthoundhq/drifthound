class EnvironmentOverviewsController < ApplicationController
  before_action :require_login_unless_public
  rescue_from ActiveRecord::RecordNotFound, with: :not_found

  def show
    @environments = Environment.where(key: params[:key]).joins(:project).preload(:project).order("projects.name", :id).to_a
    raise ActiveRecord::RecordNotFound if @environments.empty?

    @key = params[:key]
    @latest_checks = latest_checks_by_environment(@environments)
  end

  private

  def latest_checks_by_environment(environments)
    DriftCheck
      .where(environment_id: environments.map(&:id))
      .select("DISTINCT ON (environment_id) id, environment_id, status, add_count, change_count, destroy_count, created_at")
      .order(:environment_id, created_at: :desc)
      .index_by(&:environment_id)
  end

  def not_found
    render file: Rails.public_path.join("404.html"), status: :not_found, layout: false
  end
end
