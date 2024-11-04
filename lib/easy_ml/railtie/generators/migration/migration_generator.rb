require "rails/generators"
require "rails/generators/active_record/migration"

module EasyML
  module Generators
    module Migration
      class MigrationGenerator < Rails::Generators::Base
        include Rails::Generators::Migration
        namespace "easy_ml:migration"

        # Set the source directory for templates
        source_root File.expand_path("../../templates/migration", __dir__)

        # Define the migration name
        desc "Generates migrations for EasyMLModel"

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
          create_easy_ml_datasource_migration
          create_easy_ml_datasets_migration
          create_easy_ml_models_migration
          create_easy_ml_model_files_migration
          create_easy_ml_tuner_jobs_migration
          create_easy_ml_retraining_jobs_migration
          create_easy_ml_settings_migration
        end

        private

        # Generate the migration file for EasyMLModel using the template
        def create_easy_ml_models_migration
          migration_template(
            "create_easy_ml_models.rb.tt",
            "db/migrate/create_easy_ml_models.rb"
          )
        end

        def create_easy_ml_model_files_migration
          migration_template(
            "create_easy_ml_model_files.rb.tt",
            "db/migrate/create_easy_ml_model_files.rb"
          )
        end

        def create_easy_ml_datasource_migration
          migration_template(
            "create_easy_ml_datasources.rb.tt",
            "db/migrate/create_easy_ml_datasources.rb"
          )
        end

        def create_easy_ml_datasets_migration
          migration_template(
            "create_easy_ml_datasets.rb.tt",
            "db/migrate/create_easy_ml_datasets.rb"
          )
        end

        def create_easy_ml_tuner_jobs_migration
          migration_template(
            "create_easy_ml_tuner_jobs.rb.tt",
            "db/migrate/create_easy_ml_tuner_jobs.rb"
          )
        end

        def create_easy_ml_retraining_jobs_migration
          migration_template(
            "create_easy_ml_retraining_jobs.rb.tt",
            "db/migrate/create_easy_ml_retraining_jobs.rb"
          )
        end

        def create_easy_ml_settings_migration
          migration_template(
            "create_easy_ml_settings.rb.tt",
            "db/migrate/create_easy_ml_settings.rb"
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
