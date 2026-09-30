class AddEnvironmentCreatedAtIdIndexToDriftChecks < ActiveRecord::Migration[8.1]
  # Build the index without blocking inserts from scheduled scans.
  disable_ddl_transaction!

  def change
    # Serves the per-environment history query: filter on environment_id,
    # order and paginate on (created_at, id) straight from the index.
    add_index :drift_checks, [ :environment_id, :created_at, :id ],
      name: "index_drift_checks_on_environment_id_and_created_at_and_id",
      algorithm: :concurrently
  end
end
