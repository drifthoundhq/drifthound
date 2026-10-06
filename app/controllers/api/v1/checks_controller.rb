module Api
  module V1
    class ChecksController < BaseController
      class InvalidParameter < StandardError; end

      DEFAULT_LIMIT = 50
      MAX_LIMIT = 500
      COLUMNS = %i[id environment_id status add_count change_count destroy_count duration execution_number branch created_at].freeze

      rescue_from InvalidParameter do |e|
        render json: { error: e.message }, status: :bad_request
      end

      def index
        limit = parse_limit
        since_time = parse_time(:since)
        until_time = parse_time(:until)
        cursor = parse_cursor

        scope = filtered_scope
        scope = scope.where(created_at: since_time..) if since_time
        scope = scope.where(created_at: ...until_time) if until_time
        if cursor
          scope = scope.where("(drift_checks.created_at, drift_checks.id) < (?, ?)", cursor[0], cursor[1])
        end

        records = scope
          .select(COLUMNS.map { |c| DriftCheck.arel_table[c] })
          .preload(environment: :project)
          .order(created_at: :desc, id: :desc)
          .limit(limit + 1)
          .to_a

        has_more = records.size > limit
        records = records.first(limit)

        render json: {
          checks: records.map { |check| check_json(check) },
          pagination: {
            limit: limit,
            has_more: has_more,
            next_cursor: has_more ? encode_cursor(records.last) : nil
          }
        }
      end

      private

      def filtered_scope
        path = request.path_parameters
        if path[:project_key]
          project = Project.find_by!(key: path[:project_key])
          environment = project.environments.find_by!(key: path[:environment_key])
          return environment.drift_checks
        end

        scope = DriftCheck.all
        project_key = key_param(:project)
        environment_key = key_param(:environment)

        if project_key
          project = Project.find_by!(key: project_key)
          scope = scope.where(environment_id: project.environments.select(:id))
        end

        if environment_key
          environments = Environment.where(key: environment_key)
          environments = environments.where(project_id: project.id) if project
          raise ActiveRecord::RecordNotFound unless environments.exists?

          scope = scope.where(environment_id: environments.select(:id))
        end

        scope
      end

      # Only a plain string is a key; arrays and nested params are rejected
      # instead of turning into IN filters or reaching the query builder.
      def key_param(name)
        value = params[name]
        return nil if value.blank?
        raise InvalidParameter, "#{name} must be a single key" unless value.is_a?(String)

        value
      end

      def parse_limit
        return DEFAULT_LIMIT if params[:limit].blank?

        limit = Integer(params[:limit].to_s, 10)
        raise ArgumentError unless limit.between?(1, MAX_LIMIT)

        limit
      rescue ArgumentError, TypeError
        raise InvalidParameter, "limit must be an integer between 1 and #{MAX_LIMIT}"
      end

      def parse_time(name)
        value = params[name]
        return nil if value.blank?

        # Parse in UTC so a date or a timestamp without an offset does not
        # depend on the server's time zone.
        ActiveSupport::TimeZone["UTC"].iso8601(value.to_s)
      rescue ArgumentError, TypeError
        raise InvalidParameter, "#{name} must be an ISO 8601 date or timestamp"
      end

      def parse_cursor
        return nil if params[:cursor].blank?

        time, id = Base64.urlsafe_decode64(params[:cursor].to_s).split(",", 2)
        [ Time.iso8601(time), Integer(id, 10) ]
      rescue ArgumentError, TypeError
        raise InvalidParameter, "cursor is invalid"
      end

      def encode_cursor(check)
        Base64.urlsafe_encode64("#{check.created_at.utc.iso8601(6)},#{check.id}", padding: false)
      end

      def check_json(check)
        {
          id: check.id,
          project_key: check.environment.project.key,
          environment_key: check.environment.key,
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
    end
  end
end
