# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_29_175231) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "api_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.index ["token"], name: "index_api_tokens_on_token", unique: true
  end

  create_table "drift_checks", force: :cascade do |t|
    t.integer "add_count"
    t.integer "change_count"
    t.datetime "created_at", null: false
    t.integer "destroy_count"
    t.integer "duration"
    t.bigint "environment_id", null: false
    t.integer "execution_number"
    t.text "raw_output"
    t.integer "status"
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_drift_checks_on_created_at"
    t.index ["environment_id", "created_at", "id"], name: "index_drift_checks_on_environment_id_and_created_at_and_id"
    t.index ["environment_id", "execution_number"], name: "index_drift_checks_on_environment_id_and_execution_number", unique: true
    t.index ["environment_id"], name: "index_drift_checks_on_environment_id"
  end

  create_table "environments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "directory"
    t.string "key", null: false
    t.datetime "last_checked_at"
    t.string "name", null: false
    t.bigint "project_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "key"], name: "index_environments_on_project_id_and_key", unique: true
    t.index ["project_id"], name: "index_environments_on_project_id"
    t.index ["status"], name: "index_environments_on_status"
  end

  create_table "invites", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.string "email", null: false
    t.datetime "expires_at", null: false
    t.integer "role", default: 0, null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.index ["created_by_id"], name: "index_invites_on_created_by_id"
    t.index ["email"], name: "index_invites_on_email"
    t.index ["token"], name: "index_invites_on_token", unique: true
  end

  create_table "notification_channels", force: :cascade do |t|
    t.string "channel_type", null: false
    t.jsonb "config", default: {}
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.bigint "notifiable_id", null: false
    t.string "notifiable_type", null: false
    t.datetime "updated_at", null: false
    t.index ["notifiable_type", "notifiable_id", "channel_type"], name: "index_notification_channels_uniqueness", unique: true
    t.index ["notifiable_type", "notifiable_id"], name: "index_notification_channels_on_notifiable"
  end

  create_table "notification_states", force: :cascade do |t|
    t.string "channel", null: false
    t.datetime "created_at", null: false
    t.bigint "environment_id", null: false
    t.string "external_channel_id"
    t.string "external_id"
    t.integer "last_notified_status"
    t.jsonb "metadata", default: {}
    t.datetime "updated_at", null: false
    t.index ["environment_id", "channel"], name: "index_notification_states_on_environment_id_and_channel", unique: true
    t.index ["environment_id"], name: "index_notification_states_on_environment_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "branch", default: "main"
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.string "repository"
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_projects_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email"
    t.string "password_digest"
    t.string "provider"
    t.integer "role", default: 0, null: false
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true, where: "(provider IS NOT NULL)"
  end

  add_foreign_key "drift_checks", "environments"
  add_foreign_key "environments", "projects"
  add_foreign_key "invites", "users", column: "created_by_id"
  add_foreign_key "notification_states", "environments"
end
