module Api
  module V1
    class EnvironmentsController < BaseController
      before_action :set_project

      # GET /api/v1/projects/:project_key/environments
      # Optional query params:
      #   - status: filter by status (ok, drift, error, unknown)
      def index
        environments = @project.environments.order(:name)

        if params[:status].present?
          environments = environments.where(status: params[:status])
        end

        render json: environments.map { |e| environment_json(e) }
      end

      # GET /api/v1/projects/:project_key/environments/:key
      def show
        environment = @project.environments.find_by!(key: params[:key])
        render json: environment_json(environment, include_project: true)
      end

      # PATCH /api/v1/projects/:project_key/environments/:key
      # Body params:
      #   - exclude_from_metrics: true or false
      def update
        environment = @project.environments.find_by!(key: params[:key])
        value = params[:exclude_from_metrics]
        unless [ true, false ].include?(value)
          render json: { error: "exclude_from_metrics must be true or false" }, status: :unprocessable_entity
          return
        end

        environment.update!(exclude_from_metrics: value)
        render json: environment_json(environment, include_project: true)
      end

      # GET /api/v1/projects/:project_key/environments/:key/drift
      # Returns the latest drift check, with raw_output when the token may read plan output
      def drift
        environment = @project.environments.find_by!(key: params[:key])
        latest_check = environment.drift_checks.order(created_at: :desc).first

        unless latest_check
          render json: { error: "No drift checks found for this environment" }, status: :not_found
          return
        end

        render json: drift_check_json(latest_check)
      end

      private

      def set_project
        @project = Project.find_by!(key: params[:project_key])
      end

      def environment_json(env, include_project: false)
        latest_check = env.drift_checks.order(created_at: :desc).first

        json = {
          key: env.key,
          name: env.name,
          status: env.status,
          directory: env.directory,
          exclude_from_metrics: env.exclude_from_metrics,
          last_checked_at: env.last_checked_at,
          last_drift_check: latest_check ? drift_check_summary_json(latest_check) : nil
        }

        if include_project
          json[:project] = {
            key: env.project.key,
            name: env.project.name,
            repository: env.project.repository,
            branch: env.project.branch
          }
        end

        json
      end

      def drift_check_summary_json(check)
        {
          id: check.id,
          status: check.status,
          add_count: check.add_count,
          change_count: check.change_count,
          destroy_count: check.destroy_count,
          duration: check.duration,
          execution_number: check.execution_number,
          branch: check.branch,
          created_at: check.created_at,
          change_summary: check.change_summary
        }
      end

      def drift_check_json(check)
        json = drift_check_summary_json(check).merge(
          environment_key: check.environment.key,
          project_key: check.project.key
        )

        # Tokens without plan access still get the summary; raw_output_restricted
        # tells "hidden" apart from a check that had no output.
        if current_api_token.can_read_plan_output?
          json.merge(raw_output: check.raw_output)
        else
          json.merge(raw_output_restricted: true)
        end
      end
    end
  end
end
