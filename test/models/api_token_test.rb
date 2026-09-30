require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "requires name" do
    token = ApiToken.new
    token.valid?
    assert_includes token.errors[:name], "can't be blank"
  end

  test "generates token automatically" do
    token = ApiToken.create!(name: "test-token")
    assert_not_nil token.token
    assert token.token.length >= 20
  end

  test "token must be unique" do
    first = ApiToken.create!(name: "first")
    second = ApiToken.new(name: "second", token: first.token)
    assert_not second.valid?
    assert_includes second.errors[:token], "has already been taken"
  end

  test "authenticate returns token when valid" do
    token = ApiToken.create!(name: "test-token")
    found = ApiToken.authenticate(token.token)
    assert_equal token.id, found.id
  end

  test "authenticate returns nil when invalid" do
    found = ApiToken.authenticate("invalid-token")
    assert_nil found
  end

  test "authenticate returns nil when nil" do
    found = ApiToken.authenticate(nil)
    assert_nil found
  end

  test "access defaults to write" do
    token = ApiToken.create!(name: "default-access")
    assert_equal "write", token.access
    assert_not token.read_only?
  end

  test "read access is read only" do
    token = ApiToken.create!(name: "reader", access: "read")
    assert token.read_only?
  end

  test "read_plans access is read only with plan output" do
    token = ApiToken.create!(name: "plan-viewer", access: "read_plans")
    assert token.read_only?
    assert token.can_read_plan_output?
  end

  test "plan output access by level" do
    assert_not ApiToken.new(access: "read").can_read_plan_output?
    assert ApiToken.new(access: "read_plans").can_read_plan_output?
    assert ApiToken.new(access: "write").can_read_plan_output?
  end

  test "access labels cover every level" do
    assert_equal ApiToken.accesses.keys.sort, ApiToken::ACCESS_LABELS.keys.sort
    assert_equal "Read only, with plan output", ApiToken.new(access: "read_plans").access_label
  end

  test "rejects unknown access" do
    token = ApiToken.new(name: "bad", access: "admin")
    assert_not token.valid?
    assert_includes token.errors[:access], "is not included in the list"
  end

  test "rejects blank access" do
    token = ApiToken.new(name: "blank", access: nil)
    assert_not token.valid?
  end

  test "access scopes filter tokens" do
    reader = ApiToken.create!(name: "reader", access: "read")
    writer = ApiToken.create!(name: "writer", access: "write")
    assert_includes ApiToken.access_read, reader
    assert_not_includes ApiToken.access_read, writer
    assert_includes ApiToken.access_write, writer
  end
end
