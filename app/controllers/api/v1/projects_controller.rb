module Api
  module V1
    class ProjectsController < BaseController
      # GET /api/v1/projects
      # Optional query params:
      #   - with_drift: "true" to filter only projects with drifting environments
      def index
        projects = Project.includes(:environments).order(:name)

        if params[:with_drift] == "true"
          projects = projects.joins(:environments).where(environments: { status: :drift }).distinct
        end

        render json: projects.map { |p| project_json(p) }
      end

      # GET /api/v1/projects/:key
      def show
        project = Project.find_by!(key: params[:key])
        render json: project_json(project, include_environments: true)
      end

      private

      def project_json(project, include_environments: false)
        json = {
          key: project.key,
          name: project.name,
          repository: project.repository,
          branch: project.branch,
          aggregated_status: project.aggregated_status,
          last_checked_at: project.last_checked_at,
          environment_count: project.environments.count,
          drift_environment_count: project.environments.where(status: :drift).count
        }

        if include_environments
          json[:environments] = project.environments.order(:name).map { |e| environment_summary_json(e) }
        end

        json
      end

      def environment_summary_json(env)
        {
          key: env.key,
          name: env.name,
          status: env.status,
          directory: env.directory,
          last_checked_at: env.last_checked_at
        }
      end
    end
  end
end
