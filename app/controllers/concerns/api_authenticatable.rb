module ApiAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_api_token!
    before_action :enforce_api_token_access!
  end

  private

  def authenticate_api_token!
    token = extract_token_from_header
    @current_api_token = ApiToken.authenticate(token)

    unless @current_api_token
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

  def enforce_api_token_access!
    return if request.get? || request.head?
    return unless @current_api_token.read_only?

    render json: { error: "Forbidden: this API token is read-only" }, status: :forbidden
  end

  def extract_token_from_header
    header = request.headers["Authorization"]
    header&.split(" ")&.last
  end

  def current_api_token
    @current_api_token
  end
end
