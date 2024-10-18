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
        desc "Generates migrations for EasyMLModel, Dataset, and TunerRun"

        # Specify the next migration number
        def self.next_migration_number(dirname)
          sleep(1)
          if Rails::VERSION::MAJOR >= 7
            Time.now.utc.strftime("%Y%m%d%H%M%S")
          elsif ActiveRecord.timestamped_migrations
            Time.now.utc.strftime("%Y%m%d%H%M%S")
          else
            format("%.3d", (current_migration_number(dirname) + 1))
          end
        end

        # Generate the migration files using the templates
        def create_migration_files
          create_easy_ml_models_migration
          create_datasources_migration
          create_datasets_migration
          create_tuner_runs_migration
        end

        private

        # Generate the migration file for EasyMLModel using the template
        def create_easy_ml_models_migration
          migration_template(
            "create_easy_ml_models.rb.tt",
            "create_easy_ml_models.rb"
          )
        end

        # Generate the migration file for Datasource using the template
        def create_datasources_migration
          migration_template(
            "create_datasources.rb.tt",
            "create_easy_ml_datasources.rb"
          )
        end

        # Generate the migration file for Dataset using the template
        def create_datasets_migration
          migration_template(
            "create_datasets.rb.tt",
            "create_easy_ml_datasets.rb"
          )
        end

        # Generate the migration file for TunerRun using the template
        def create_tuner_runs_migration
          migration_template(
            "create_tuner_runs.rb.tt",
            "create_easy_ml_tuner_runs.rb"
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
