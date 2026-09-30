require "test_helper"

class ApiTokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @editor = users(:editor)
    @viewer = users(:viewer)
    @token = api_tokens(:one)
  end

  # Index tests
  test "admin can view api tokens index" do
    sign_in_as(@admin)
    get api_tokens_path
    assert_response :success
    assert_select "h1", "API Tokens"
  end

  test "editor cannot view api tokens index" do
    sign_in_as(@editor)
    get api_tokens_path
    assert_redirected_to root_path
  end

  test "viewer cannot view api tokens index" do
    sign_in_as(@viewer)
    get api_tokens_path
    assert_redirected_to root_path
  end

  test "guest cannot view api tokens index" do
    get api_tokens_path
    assert_redirected_to login_path
  end

  # Create tests
  test "admin can create api token" do
    sign_in_as(@admin)
    assert_difference("ApiToken.count", 1) do
      post api_tokens_path, params: { api_token: { name: "New CI Token" } }
    end
    assert_redirected_to api_tokens_path
    assert_match "API token 'New CI Token' was created", flash[:notice]
    assert_not_nil flash[:token_value]

    token = ApiToken.last
    assert_equal "New CI Token", token.name
    assert token.token.present?
  end

  test "admin creates write token by default" do
    sign_in_as(@admin)
    post api_tokens_path, params: { api_token: { name: "Default Access" } }
    assert_equal "write", ApiToken.find_by(name: "Default Access").access
  end

  test "admin can create read only api token" do
    sign_in_as(@admin)
    assert_difference("ApiToken.count", 1) do
      post api_tokens_path, params: { api_token: { name: "Dashboard", access: "read" } }
    end
    assert_redirected_to api_tokens_path
    assert ApiToken.find_by(name: "Dashboard").read_only?
  end

  test "admin can create read only api token with plan output" do
    sign_in_as(@admin)
    post api_tokens_path, params: { api_token: { name: "Plan Viewer", access: "read_plans" } }

    assert_redirected_to api_tokens_path
    token = ApiToken.find_by(name: "Plan Viewer")
    assert token.read_only?
    assert token.can_read_plan_output?
  end

  test "cannot create api token with unknown access" do
    sign_in_as(@admin)
    assert_no_difference("ApiToken.count") do
      post api_tokens_path, params: { api_token: { name: "Bad", access: "admin" } }
    end
    assert_response :unprocessable_entity
  end

  test "index shows token access" do
    ApiToken.create!(name: "Reporting", access: "read")
    ApiToken.create!(name: "Plan Viewer", access: "read_plans")
    sign_in_as(@admin)
    get api_tokens_path
    assert_select "select[name=?] option", "api_token[access]", 3
    assert_select ".col-access", text: "Read only"
    assert_select ".col-access", text: "Read only, with plan output"
    assert_select ".col-access", text: "Read and write"
  end

  test "editor cannot create api token" do
    sign_in_as(@editor)
    assert_no_difference("ApiToken.count") do
      post api_tokens_path, params: { api_token: { name: "Attempted Token" } }
    end
    assert_redirected_to root_path
  end

  test "viewer cannot create api token" do
    sign_in_as(@viewer)
    assert_no_difference("ApiToken.count") do
      post api_tokens_path, params: { api_token: { name: "Attempted Token" } }
    end
    assert_redirected_to root_path
  end

  test "guest cannot create api token" do
    assert_no_difference("ApiToken.count") do
      post api_tokens_path, params: { api_token: { name: "Attempted Token" } }
    end
    assert_redirected_to login_path
  end

  test "cannot create api token without name" do
    sign_in_as(@admin)
    assert_no_difference("ApiToken.count") do
      post api_tokens_path, params: { api_token: { name: "" } }
    end
    assert_response :unprocessable_entity
  end

  # Destroy tests
  test "admin can delete api token" do
    sign_in_as(@admin)
    assert_difference("ApiToken.count", -1) do
      delete api_token_path(@token)
    end
    assert_redirected_to api_tokens_path
    assert_match "API token 'Test Token One' was deleted", flash[:notice]
  end

  test "editor cannot delete api token" do
    sign_in_as(@editor)
    assert_no_difference("ApiToken.count") do
      delete api_token_path(@token)
    end
    assert_redirected_to root_path
  end

  test "viewer cannot delete api token" do
    sign_in_as(@viewer)
    assert_no_difference("ApiToken.count") do
      delete api_token_path(@token)
    end
    assert_redirected_to root_path
  end

  test "guest cannot delete api token" do
    assert_no_difference("ApiToken.count") do
      delete api_token_path(@token)
    end
    assert_redirected_to login_path
  end

  private

  def sign_in_as(user)
    post login_path, params: { email: user.email, password: "testpass1" }
  end
end
