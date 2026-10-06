class AddBranchToDriftChecks < ActiveRecord::Migration[8.1]
  def change
    add_column :drift_checks, :branch, :string
  end
end
