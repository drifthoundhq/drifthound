class ApiTokensController < ApplicationController
  before_action :require_login
  before_action :set_api_token, only: [ :destroy ]

  def index
    authorize ApiToken
    @api_tokens = policy_scope(ApiToken).order(created_at: :desc)
    @new_api_token = ApiToken.new
  end

  def create
    authorize ApiToken
    @api_token = ApiToken.new(api_token_params)

    if @api_token.save
      flash[:notice] = "API token '#{@api_token.name}' was created. Token: #{@api_token.token}"
      flash[:token_value] = @api_token.token
      redirect_to api_tokens_path
    else
      @api_tokens = policy_scope(ApiToken).order(created_at: :desc)
      @new_api_token = @api_token
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @api_token
    name = @api_token.name
    @api_token.destroy
    redirect_to api_tokens_path, notice: "API token '#{name}' was deleted."
  end

  private

  def set_api_token
    @api_token = ApiToken.find(params[:id])
  end

  def api_token_params
    params.require(:api_token).permit(:name, :access)
  end
end
