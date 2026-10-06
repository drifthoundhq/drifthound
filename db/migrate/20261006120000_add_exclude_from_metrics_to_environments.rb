class AddExcludeFromMetricsToEnvironments < ActiveRecord::Migration[8.1]
  def change
    add_column :environments, :exclude_from_metrics, :boolean, null: false, default: false
  end
end
