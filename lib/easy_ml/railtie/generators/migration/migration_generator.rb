# lib/railtie/generators/migration/migration_generator.rb
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
        desc "Generates a migration for EasyMLModel with version and file for remote storage"

        # Define the migration name; can be customized if needed
        def self.migration_name
          "create_easy_ml_models"
        end

        # Specify the next migration number
        def self.next_migration_number(dirname)
          if ActiveRecord.timestamped_migrations
            Time.now.utc.strftime("%Y%m%d%H%M%S")
          else
            format("%.3d", (current_migration_number(dirname) + 1))
          end
        end

        # Generate the migration file using the template
        def create_migration_file
          migration_template "create_easy_ml_models.rb.tt",
                             "db/migrate/#{self.class.migration_name}.rb"
        end
      end
    end
  end
end
