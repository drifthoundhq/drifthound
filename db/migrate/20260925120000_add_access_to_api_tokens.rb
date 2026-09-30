class AddAccessToApiTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :api_tokens, :access, :string, null: false, default: "write"
  end
end
