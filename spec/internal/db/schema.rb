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

ActiveRecord::Schema[7.2].define(version: 2025_02_04_163629) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "easy_ml_column_histories", force: :cascade do |t|
    t.integer "column_id", null: false
    t.integer "dataset_id", null: false
    t.string "name", null: false
    t.string "description"
    t.string "datatype"
    t.string "polars_datatype"
    t.boolean "is_target", default: false
    t.boolean "hidden", default: false
    t.boolean "drop_if_null", default: false
    t.json "preprocessing_steps"
    t.json "sample_values"
    t.json "statistics"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "history_started_at", null: false
    t.datetime "history_ended_at"
    t.integer "history_user_id"
    t.string "snapshot_id"
    t.boolean "is_date_column", default: false
    t.string "computed_by"
    t.boolean "is_computed", default: false
    t.bigint "feature_id"
    t.datetime "learned_at", precision: nil
    t.string "last_datasource_sha"
    t.index ["column_id"], name: "index_easy_ml_column_histories_on_column_id"
    t.index ["computed_by"], name: "index_easy_ml_column_histories_on_computed_by"
    t.index ["dataset_id", "name"], name: "index_easy_ml_column_histories_on_dataset_id_and_name"
    t.index ["datatype"], name: "index_easy_ml_column_histories_on_datatype"
    t.index ["drop_if_null"], name: "index_easy_ml_column_histories_on_drop_if_null"
    t.index ["feature_id"], name: "index_easy_ml_column_histories_on_feature_id"
    t.index ["hidden"], name: "index_easy_ml_column_histories_on_hidden"
    t.index ["history_ended_at"], name: "index_easy_ml_column_histories_on_history_ended_at"
    t.index ["history_started_at"], name: "index_easy_ml_column_histories_on_history_started_at"
    t.index ["history_user_id"], name: "index_easy_ml_column_histories_on_history_user_id"
    t.index ["is_computed"], name: "index_easy_ml_column_histories_on_is_computed"
    t.index ["is_date_column"], name: "index_easy_ml_column_histories_on_is_date_column"
    t.index ["is_target"], name: "index_easy_ml_column_histories_on_is_target"
    t.index ["last_datasource_sha"], name: "index_easy_ml_column_histories_on_last_datasource_sha"
    t.index ["learned_at"], name: "index_easy_ml_column_histories_on_learned_at"
    t.index ["snapshot_id"], name: "index_easy_ml_column_histories_on_snapshot_id"
  end

  create_table "easy_ml_columns", force: :cascade do |t|
    t.bigint "dataset_id", null: false
    t.string "name", null: false
    t.string "description"
    t.string "datatype"
    t.string "polars_datatype"
    t.boolean "is_target", default: false
    t.boolean "hidden", default: false
    t.boolean "drop_if_null", default: false
    t.json "preprocessing_steps"
    t.json "sample_values"
    t.json "statistics"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_date_column", default: false
    t.string "computed_by"
    t.boolean "is_computed", default: false
    t.bigint "feature_id"
    t.datetime "learned_at", precision: nil
    t.string "last_datasource_sha"
    t.index ["computed_by"], name: "index_easy_ml_columns_on_computed_by"
    t.index ["dataset_id", "name"], name: "index_easy_ml_columns_on_dataset_id_and_name", unique: true
    t.index ["datatype"], name: "index_easy_ml_columns_on_datatype"
    t.index ["drop_if_null"], name: "index_easy_ml_columns_on_drop_if_null"
    t.index ["feature_id"], name: "index_easy_ml_columns_on_feature_id"
    t.index ["hidden"], name: "index_easy_ml_columns_on_hidden"
    t.index ["is_computed"], name: "index_easy_ml_columns_on_is_computed"
    t.index ["is_date_column"], name: "index_easy_ml_columns_on_is_date_column"
    t.index ["is_target"], name: "index_easy_ml_columns_on_is_target"
    t.index ["last_datasource_sha"], name: "index_easy_ml_columns_on_last_datasource_sha"
    t.index ["learned_at"], name: "index_easy_ml_columns_on_learned_at"
  end

  create_table "easy_ml_dataset_histories", force: :cascade do |t|
    t.integer "dataset_id", null: false
    t.string "name", null: false
    t.string "description"
    t.string "dataset_type"
    t.string "status"
    t.string "version"
    t.integer "datasource_id"
    t.string "root_dir"
    t.json "configuration"
    t.integer "num_rows"
    t.string "workflow_status"
    t.json "statistics"
    t.json "schema"
    t.datetime "refreshed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "history_started_at", null: false
    t.datetime "history_ended_at"
    t.integer "history_user_id"
    t.string "snapshot_id"
    t.string "last_datasource_sha"
    t.index ["created_at"], name: "index_easy_ml_dataset_histories_on_created_at"
    t.index ["dataset_id"], name: "index_easy_ml_dataset_histories_on_dataset_id"
    t.index ["dataset_type"], name: "index_easy_ml_dataset_histories_on_dataset_type"
    t.index ["datasource_id"], name: "index_easy_ml_dataset_histories_on_datasource_id"
    t.index ["history_ended_at"], name: "index_easy_ml_dataset_histories_on_history_ended_at"
    t.index ["history_started_at"], name: "index_easy_ml_dataset_histories_on_history_started_at"
    t.index ["history_user_id"], name: "index_easy_ml_dataset_histories_on_history_user_id"
    t.index ["last_datasource_sha"], name: "index_easy_ml_dataset_histories_on_last_datasource_sha"
    t.index ["name", "status"], name: "index_easy_ml_dataset_histories_on_name_and_status"
    t.index ["name"], name: "index_easy_ml_dataset_histories_on_name"
    t.index ["refreshed_at"], name: "index_easy_ml_dataset_histories_on_refreshed_at"
    t.index ["snapshot_id"], name: "index_easy_ml_dataset_histories_on_snapshot_id"
    t.index ["status"], name: "index_easy_ml_dataset_histories_on_status"
    t.index ["workflow_status"], name: "index_easy_ml_dataset_histories_on_workflow_status"
  end

  create_table "easy_ml_datasets", force: :cascade do |t|
    t.string "name", null: false
    t.string "description"
    t.string "dataset_type"
    t.string "status"
    t.string "version"
    t.bigint "datasource_id"
    t.string "root_dir"
    t.json "configuration"
    t.bigint "num_rows"
    t.string "workflow_status"
    t.json "statistics"
    t.json "schema"
    t.datetime "refreshed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "last_datasource_sha"
    t.index ["created_at"], name: "index_easy_ml_datasets_on_created_at"
    t.index ["dataset_type"], name: "index_easy_ml_datasets_on_dataset_type"
    t.index ["datasource_id"], name: "index_easy_ml_datasets_on_datasource_id"
    t.index ["last_datasource_sha"], name: "index_easy_ml_datasets_on_last_datasource_sha"
    t.index ["name", "status"], name: "index_easy_ml_datasets_on_name_and_status"
    t.index ["name"], name: "index_easy_ml_datasets_on_name"
    t.index ["refreshed_at"], name: "index_easy_ml_datasets_on_refreshed_at"
    t.index ["status"], name: "index_easy_ml_datasets_on_status"
    t.index ["workflow_status"], name: "index_easy_ml_datasets_on_workflow_status"
  end

  create_table "easy_ml_datasource_histories", force: :cascade do |t|
    t.integer "datasource_id", null: false
    t.string "name", null: false
    t.string "datasource_type"
    t.string "root_dir"
    t.json "configuration"
    t.datetime "refreshed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "history_started_at", null: false
    t.datetime "history_ended_at"
    t.integer "history_user_id"
    t.string "snapshot_id"
    t.string "sha"
    t.index ["created_at"], name: "index_easy_ml_datasource_histories_on_created_at"
    t.index ["datasource_id"], name: "index_easy_ml_datasource_histories_on_datasource_id"
    t.index ["datasource_type"], name: "index_easy_ml_datasource_histories_on_datasource_type"
    t.index ["history_ended_at"], name: "index_easy_ml_datasource_histories_on_history_ended_at"
    t.index ["history_started_at"], name: "index_easy_ml_datasource_histories_on_history_started_at"
    t.index ["history_user_id"], name: "index_easy_ml_datasource_histories_on_history_user_id"
    t.index ["refreshed_at"], name: "index_easy_ml_datasource_histories_on_refreshed_at"
    t.index ["sha"], name: "index_easy_ml_datasource_histories_on_sha"
    t.index ["snapshot_id"], name: "index_easy_ml_datasource_histories_on_snapshot_id"
  end

  create_table "easy_ml_datasources", force: :cascade do |t|
    t.string "name", null: false
    t.string "datasource_type"
    t.string "root_dir"
    t.json "configuration"
    t.datetime "refreshed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "sha"
    t.index ["created_at"], name: "index_easy_ml_datasources_on_created_at"
    t.index ["datasource_type"], name: "index_easy_ml_datasources_on_datasource_type"
    t.index ["refreshed_at"], name: "index_easy_ml_datasources_on_refreshed_at"
    t.index ["sha"], name: "index_easy_ml_datasources_on_sha"
  end

  create_table "easy_ml_deploys", force: :cascade do |t|
    t.bigint "model_id"
    t.bigint "model_history_id"
    t.bigint "retraining_run_id"
    t.bigint "model_file_id"
    t.string "status", null: false
    t.string "trigger", default: "manual"
    t.text "stacktrace"
    t.string "snapshot_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_easy_ml_deploys_on_created_at"
    t.index ["model_file_id"], name: "index_easy_ml_deploys_on_model_file_id"
    t.index ["model_history_id"], name: "index_easy_ml_deploys_on_model_history_id"
    t.index ["model_id"], name: "index_easy_ml_deploys_on_model_id"
    t.index ["retraining_run_id"], name: "index_easy_ml_deploys_on_retraining_run_id"
    t.index ["snapshot_id"], name: "index_easy_ml_deploys_on_snapshot_id"
    t.index ["status"], name: "index_easy_ml_deploys_on_status"
    t.index ["trigger"], name: "index_easy_ml_deploys_on_trigger"
  end

  create_table "easy_ml_event_contexts", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.jsonb "context", default: {}, null: false
    t.string "format"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["context"], name: "index_easy_ml_event_contexts_on_context", using: :gin
    t.index ["event_id"], name: "index_easy_ml_event_contexts_on_event_id"
  end

  create_table "easy_ml_events", force: :cascade do |t|
    t.string "name", null: false
    t.string "status", null: false
    t.string "eventable_type"
    t.bigint "eventable_id"
    t.text "stacktrace"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_easy_ml_events_on_created_at"
    t.index ["eventable_id"], name: "index_easy_ml_events_on_eventable_id"
    t.index ["eventable_type", "eventable_id"], name: "index_easy_ml_events_on_eventable_type_and_eventable_id"
    t.index ["eventable_type"], name: "index_easy_ml_events_on_eventable_type"
    t.index ["name"], name: "index_easy_ml_events_on_name"
    t.index ["status"], name: "index_easy_ml_events_on_status"
  end

  create_table "easy_ml_feature_histories", force: :cascade do |t|
    t.integer "feature_id", null: false
    t.integer "dataset_id", null: false
    t.string "name"
    t.integer "version"
    t.string "feature_class", null: false
    t.integer "feature_position"
    t.integer "batch_size"
    t.boolean "needs_fit"
    t.string "sha"
    t.string "primary_key"
    t.datetime "applied_at"
    t.datetime "fit_at"
    t.integer "refresh_every"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "history_started_at", null: false
    t.datetime "history_ended_at"
    t.integer "history_user_id"
    t.string "snapshot_id"
    t.string "workflow_status"
    t.index ["applied_at"], name: "index_easy_ml_feature_histories_on_applied_at"
    t.index ["batch_size"], name: "index_easy_ml_feature_histories_on_batch_size"
    t.index ["dataset_id", "feature_position"], name: "idx_feature_histories_on_dataset_and_position"
    t.index ["dataset_id", "name"], name: "index_easy_ml_feature_histories_on_dataset_id_and_name"
    t.index ["feature_class"], name: "index_easy_ml_feature_histories_on_feature_class"
    t.index ["feature_id"], name: "index_easy_ml_feature_histories_on_feature_id"
    t.index ["fit_at"], name: "index_easy_ml_feature_histories_on_fit_at"
    t.index ["history_ended_at"], name: "index_easy_ml_feature_histories_on_history_ended_at"
    t.index ["history_started_at"], name: "index_easy_ml_feature_histories_on_history_started_at"
    t.index ["history_user_id"], name: "index_easy_ml_feature_histories_on_history_user_id"
    t.index ["name"], name: "index_easy_ml_feature_histories_on_name"
    t.index ["needs_fit"], name: "index_easy_ml_feature_histories_on_needs_fit"
    t.index ["refresh_every"], name: "index_easy_ml_feature_histories_on_refresh_every"
    t.index ["sha"], name: "index_easy_ml_feature_histories_on_sha"
    t.index ["snapshot_id"], name: "index_easy_ml_feature_histories_on_snapshot_id"
    t.index ["version"], name: "index_easy_ml_feature_histories_on_version"
    t.index ["workflow_status"], name: "index_easy_ml_feature_histories_on_workflow_status"
  end

  create_table "easy_ml_features", force: :cascade do |t|
    t.bigint "dataset_id", null: false
    t.string "name"
    t.bigint "version"
    t.string "feature_class", null: false
    t.integer "feature_position"
    t.integer "batch_size"
    t.boolean "needs_fit"
    t.string "sha"
    t.string "primary_key", array: true
    t.datetime "applied_at"
    t.datetime "fit_at"
    t.bigint "refresh_every"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "workflow_status"
    t.index ["applied_at"], name: "index_easy_ml_features_on_applied_at"
    t.index ["batch_size"], name: "index_easy_ml_features_on_batch_size"
    t.index ["dataset_id", "feature_position"], name: "idx_features_on_dataset_and_position"
    t.index ["dataset_id", "name"], name: "idx_features_on_dataset_and_name", unique: true
    t.index ["feature_class"], name: "index_easy_ml_features_on_feature_class"
    t.index ["fit_at"], name: "index_easy_ml_features_on_fit_at"
    t.index ["name"], name: "index_easy_ml_features_on_name"
    t.index ["needs_fit"], name: "index_easy_ml_features_on_needs_fit"
    t.index ["refresh_every"], name: "index_easy_ml_features_on_refresh_every"
    t.index ["sha"], name: "index_easy_ml_features_on_sha"
    t.index ["version"], name: "index_easy_ml_features_on_version"
    t.index ["workflow_status"], name: "index_easy_ml_features_on_workflow_status"
  end

  create_table "easy_ml_model_file_histories", force: :cascade do |t|
    t.integer "model_file_id", null: false
    t.string "filename", null: false
    t.json "configuration"
    t.string "model_type"
    t.integer "model_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "history_started_at", null: false
    t.datetime "history_ended_at"
    t.integer "history_user_id"
    t.string "snapshot_id"
    t.index ["created_at"], name: "index_easy_ml_model_file_histories_on_created_at"
    t.index ["filename"], name: "index_easy_ml_model_file_histories_on_filename"
    t.index ["history_ended_at"], name: "index_easy_ml_model_file_histories_on_history_ended_at"
    t.index ["history_started_at"], name: "index_easy_ml_model_file_histories_on_history_started_at"
    t.index ["history_user_id"], name: "index_easy_ml_model_file_histories_on_history_user_id"
    t.index ["model_file_id"], name: "index_easy_ml_model_file_histories_on_model_file_id"
    t.index ["model_id"], name: "index_easy_ml_model_file_histories_on_model_id"
    t.index ["model_type"], name: "index_easy_ml_model_file_histories_on_model_type"
    t.index ["snapshot_id"], name: "index_easy_ml_model_file_histories_on_snapshot_id"
  end

  create_table "easy_ml_model_files", force: :cascade do |t|
    t.string "filename", null: false
    t.json "configuration"
    t.string "model_type"
    t.bigint "model_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_easy_ml_model_files_on_created_at"
    t.index ["filename"], name: "index_easy_ml_model_files_on_filename"
    t.index ["model_id"], name: "index_easy_ml_model_files_on_model_id"
    t.index ["model_type"], name: "index_easy_ml_model_files_on_model_type"
  end

  create_table "easy_ml_model_histories", force: :cascade do |t|
    t.integer "model_id", null: false
    t.string "name", null: false
    t.string "model_type"
    t.string "status"
    t.integer "dataset_id"
    t.integer "model_file_id"
    t.json "configuration"
    t.string "version", null: false
    t.string "root_dir"
    t.json "file"
    t.string "sha"
    t.datetime "last_trained_at"
    t.boolean "is_training"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "history_started_at", null: false
    t.datetime "history_ended_at"
    t.integer "history_user_id"
    t.string "snapshot_id"
    t.string "slug"
    t.index ["created_at"], name: "index_easy_ml_model_histories_on_created_at"
    t.index ["dataset_id"], name: "index_easy_ml_model_histories_on_dataset_id"
    t.index ["history_ended_at"], name: "index_easy_ml_model_histories_on_history_ended_at"
    t.index ["history_started_at"], name: "index_easy_ml_model_histories_on_history_started_at"
    t.index ["history_user_id"], name: "index_easy_ml_model_histories_on_history_user_id"
    t.index ["is_training"], name: "index_easy_ml_model_histories_on_is_training"
    t.index ["last_trained_at"], name: "index_easy_ml_model_histories_on_last_trained_at"
    t.index ["model_file_id"], name: "index_easy_ml_model_histories_on_model_file_id"
    t.index ["model_id"], name: "index_easy_ml_model_histories_on_model_id"
    t.index ["model_type"], name: "index_easy_ml_model_histories_on_model_type"
    t.index ["name", "status"], name: "index_easy_ml_model_histories_on_name_and_status"
    t.index ["name", "version"], name: "index_easy_ml_model_histories_on_name_and_version"
    t.index ["name"], name: "index_easy_ml_model_histories_on_name"
    t.index ["sha"], name: "index_easy_ml_model_histories_on_sha"
    t.index ["slug"], name: "index_easy_ml_model_histories_on_slug"
    t.index ["snapshot_id"], name: "index_easy_ml_model_histories_on_snapshot_id"
    t.index ["status"], name: "index_easy_ml_model_histories_on_status"
    t.index ["version"], name: "index_easy_ml_model_histories_on_version"
  end

  create_table "easy_ml_models", force: :cascade do |t|
    t.string "name", null: false
    t.string "model_type"
    t.string "status"
    t.bigint "dataset_id"
    t.bigint "model_file_id"
    t.json "configuration"
    t.string "version", null: false
    t.string "root_dir"
    t.json "file"
    t.string "sha"
    t.datetime "last_trained_at"
    t.boolean "is_training"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug", null: false
    t.index ["created_at"], name: "index_easy_ml_models_on_created_at"
    t.index ["dataset_id"], name: "index_easy_ml_models_on_dataset_id"
    t.index ["is_training"], name: "index_easy_ml_models_on_is_training"
    t.index ["last_trained_at"], name: "index_easy_ml_models_on_last_trained_at"
    t.index ["model_file_id"], name: "index_easy_ml_models_on_model_file_id"
    t.index ["model_type"], name: "index_easy_ml_models_on_model_type"
    t.index ["name", "status"], name: "index_easy_ml_models_on_name_and_status"
    t.index ["name", "version"], name: "index_easy_ml_models_on_name_and_version"
    t.index ["name"], name: "index_easy_ml_models_on_name"
    t.index ["sha"], name: "index_easy_ml_models_on_sha"
    t.index ["slug"], name: "index_easy_ml_models_on_slug", unique: true
    t.index ["status"], name: "index_easy_ml_models_on_status"
    t.index ["version"], name: "index_easy_ml_models_on_version"
  end

  create_table "easy_ml_predictions", force: :cascade do |t|
    t.bigint "model_id", null: false
    t.bigint "model_history_id"
    t.string "prediction_type"
    t.jsonb "prediction_value"
    t.jsonb "raw_input"
    t.jsonb "normalized_input"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_easy_ml_predictions_on_created_at"
    t.index ["model_history_id"], name: "index_easy_ml_predictions_on_model_history_id"
    t.index ["model_id"], name: "index_easy_ml_predictions_on_model_id"
  end

  create_table "easy_ml_retraining_jobs", force: :cascade do |t|
    t.bigint "model_id"
    t.string "frequency", null: false
    t.json "at", null: false
    t.json "evaluator"
    t.boolean "tuning_enabled", default: false
    t.json "tuner_config"
    t.string "tuning_frequency"
    t.datetime "last_tuning_at"
    t.boolean "active", default: true
    t.string "status", default: "pending"
    t.datetime "last_run_at"
    t.string "metric", null: false
    t.string "direction", null: false
    t.float "threshold", null: false
    t.boolean "auto_deploy", default: false
    t.boolean "batch_mode"
    t.integer "batch_size"
    t.integer "batch_overlap"
    t.string "batch_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_easy_ml_retraining_jobs_on_active"
    t.index ["auto_deploy"], name: "index_easy_ml_retraining_jobs_on_auto_deploy"
    t.index ["batch_mode"], name: "index_easy_ml_retraining_jobs_on_batch_mode"
    t.index ["last_run_at"], name: "index_easy_ml_retraining_jobs_on_last_run_at"
    t.index ["last_tuning_at"], name: "index_easy_ml_retraining_jobs_on_last_tuning_at"
    t.index ["model_id"], name: "index_easy_ml_retraining_jobs_on_model_id"
    t.index ["tuning_enabled"], name: "index_easy_ml_retraining_jobs_on_tuning_enabled"
  end

  create_table "easy_ml_retraining_runs", force: :cascade do |t|
    t.bigint "model_id"
    t.bigint "model_history_id"
    t.bigint "model_file_id"
    t.bigint "retraining_job_id", null: false
    t.bigint "tuner_job_id"
    t.string "status", default: "pending"
    t.float "metric_value"
    t.float "threshold"
    t.string "trigger", default: "manual"
    t.string "threshold_direction"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.text "error_message"
    t.jsonb "metadata"
    t.jsonb "metrics"
    t.jsonb "best_params"
    t.string "wandb_url"
    t.string "snapshot_id"
    t.boolean "deployable"
    t.boolean "is_deploying"
    t.boolean "deployed"
    t.bigint "deploy_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["completed_at"], name: "index_easy_ml_retraining_runs_on_completed_at"
    t.index ["created_at"], name: "index_easy_ml_retraining_runs_on_created_at"
    t.index ["deploy_id"], name: "index_easy_ml_retraining_runs_on_deploy_id"
    t.index ["deployable"], name: "index_easy_ml_retraining_runs_on_deployable"
    t.index ["is_deploying"], name: "index_easy_ml_retraining_runs_on_is_deploying"
    t.index ["model_history_id"], name: "index_easy_ml_retraining_runs_on_model_history_id"
    t.index ["model_id"], name: "index_easy_ml_retraining_runs_on_model_id"
    t.index ["retraining_job_id"], name: "index_easy_ml_retraining_runs_on_retraining_job_id"
    t.index ["snapshot_id"], name: "index_easy_ml_retraining_runs_on_snapshot_id"
    t.index ["started_at"], name: "index_easy_ml_retraining_runs_on_started_at"
    t.index ["status"], name: "index_easy_ml_retraining_runs_on_status"
    t.index ["trigger"], name: "index_easy_ml_retraining_runs_on_trigger"
    t.index ["tuner_job_id"], name: "index_easy_ml_retraining_runs_on_tuner_job_id"
    t.index ["wandb_url"], name: "index_easy_ml_retraining_runs_on_wandb_url"
  end

  create_table "easy_ml_settings", force: :cascade do |t|
    t.json "configuration"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "easy_ml_splitter_histories", force: :cascade do |t|
    t.integer "splitter_id", null: false
    t.string "splitter_type", null: false
    t.json "configuration"
    t.integer "dataset_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "history_started_at", null: false
    t.datetime "history_ended_at"
    t.integer "history_user_id"
    t.string "snapshot_id"
    t.index ["created_at"], name: "index_easy_ml_splitter_histories_on_created_at"
    t.index ["dataset_id"], name: "index_easy_ml_splitter_histories_on_dataset_id"
    t.index ["history_ended_at"], name: "index_easy_ml_splitter_histories_on_history_ended_at"
    t.index ["history_started_at"], name: "index_easy_ml_splitter_histories_on_history_started_at"
    t.index ["history_user_id"], name: "index_easy_ml_splitter_histories_on_history_user_id"
    t.index ["snapshot_id"], name: "index_easy_ml_splitter_histories_on_snapshot_id"
    t.index ["splitter_id"], name: "index_easy_ml_splitter_histories_on_splitter_id"
    t.index ["splitter_type"], name: "index_easy_ml_splitter_histories_on_splitter_type"
  end

  create_table "easy_ml_splitters", force: :cascade do |t|
    t.string "splitter_type", null: false
    t.json "configuration"
    t.bigint "dataset_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_easy_ml_splitters_on_created_at"
    t.index ["dataset_id"], name: "index_easy_ml_splitters_on_dataset_id"
    t.index ["splitter_type"], name: "index_easy_ml_splitters_on_splitter_type"
  end

  create_table "easy_ml_tuner_jobs", force: :cascade do |t|
    t.json "config", null: false
    t.bigint "best_tuner_run_id"
    t.bigint "model_id", null: false
    t.string "status"
    t.string "direction", default: "minimize"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.jsonb "metadata"
    t.string "wandb_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["best_tuner_run_id"], name: "index_easy_ml_tuner_jobs_on_best_tuner_run_id"
    t.index ["completed_at"], name: "index_easy_ml_tuner_jobs_on_completed_at"
    t.index ["model_id"], name: "index_easy_ml_tuner_jobs_on_model_id"
    t.index ["started_at"], name: "index_easy_ml_tuner_jobs_on_started_at"
    t.index ["status"], name: "index_easy_ml_tuner_jobs_on_status"
    t.index ["wandb_url"], name: "index_easy_ml_tuner_jobs_on_wandb_url"
  end

  create_table "easy_ml_tuner_runs", force: :cascade do |t|
    t.bigint "tuner_job_id", null: false
    t.json "hyperparameters", null: false
    t.float "value"
    t.integer "trial_number"
    t.string "status"
    t.string "wandb_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_easy_ml_tuner_runs_on_status"
    t.index ["tuner_job_id", "trial_number"], name: "idx_tuner_runs_and_trial_number"
    t.index ["tuner_job_id", "value"], name: "index_easy_ml_tuner_runs_on_tuner_job_id_and_value"
    t.index ["wandb_url"], name: "index_easy_ml_tuner_runs_on_wandb_url"
  end

  add_foreign_key "easy_ml_event_contexts", "easy_ml_events", column: "event_id"
end
