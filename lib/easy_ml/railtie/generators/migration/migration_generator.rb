require "rails/generators"
require "rails/generators/active_record/migration"

module EasyML
  module Railtie
    module Generators
      module Migration
        class MigrationGenerator < Rails::Generators::Base
          include Rails::Generators::Migration
          namespace "easy_ml:migration"

          # Set the source directory for templates
          source_root File.expand_path("../../templates/migration", __dir__)

          # Define the migration name
          desc "Generates migrations for EasyMLModel"

          # Define the order of migrations
          MIGRATION_ORDER = %w[
            create_easy_ml_datasources
            create_easy_ml_datasets
            create_easy_ml_columns
            create_easy_ml_models
            create_easy_ml_model_files
            create_easy_ml_tuner_jobs
            create_easy_ml_retraining_jobs
            create_easy_ml_settings
            create_easy_ml_events
            create_easy_ml_features
            create_easy_ml_splitters
            create_easy_ml_splitter_histories
            create_easy_ml_deploys
            create_easy_ml_datasource_histories
            create_easy_ml_dataset_histories
            create_easy_ml_column_histories
            create_easy_ml_model_histories
            create_easy_ml_model_file_histories
            create_easy_ml_feature_histories
            create_easy_ml_predictions
            create_easy_ml_event_contexts
            add_workflow_status_to_easy_ml_features
            drop_path_from_easy_ml_model_files
            add_is_date_column_to_easy_ml_columns
            add_computed_columns_to_easy_ml_columns
            add_slug_to_easy_ml_models
            add_default_to_is_target
            remove_preprocessor_statistics_from_easy_ml_datasets
            add_learned_at_to_easy_ml_columns
            add_sha_to_datasources_datasets_and_columns
            add_last_feature_sha_to_columns
            add_extra_metadata_to_columns
            create_easy_ml_lineages
            update_preprocessing_steps_to_jsonb
            add_raw_schema_to_datasets
            remove_evaluator_from_retraining_jobs
            add_unique_constraint_to_easy_ml_model_names
            add_is_primary_key_to_easy_ml_columns
            create_easy_ml_pca_models
            add_pca_model_id_to_easy_ml_columns
            add_workflow_status_to_easy_ml_dataset_histories
            add_metadata_to_easy_ml_predictions
          ].freeze

          # Specify the next migration number
          def self.next_migration_number(dirname)
            sleep(1)
            if ActiveRecord.version < Gem::Version.new("7")
              Time.now.utc.strftime("%Y%m%d%H%M%S")
            elsif ActiveRecord.timestamped_migrations
              Time.now.utc.strftime("%Y%m%d%H%M%S")
            else
              format("%.3d", (current_migration_number(dirname) + 1))
            end
          end

          # Generate the migration files using the templates
          def create_migration_files
            # Check for existing migrations first
            existing_migrations = Dir.glob(Rails.root.join("db/migrate/*_*.rb")).map do |f|
              File.basename(f).sub(/^\d+_/, "").sub(/\.rb$/, "")
            end

            # Create migrations in order if they don't exist
            MIGRATION_ORDER.each do |migration_name|
              next if existing_migrations.include?(migration_name)
              install_migration(migration_name)
            end
          end

          private

          def install_migration(migration_name)
            migration_template(
              "#{migration_name}.rb.tt",
              "db/migrate/#{migration_name}.rb"
            )
          end

          # Get the next migration number
          def next_migration_number
            self.class.next_migration_number(Rails.root.join("db/migrate"))
          end
        end
      end
    end
  end
end
