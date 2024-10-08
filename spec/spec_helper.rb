# frozen_string_literal: true

require "bundler/setup"
require "combustion"
Bundler.require :default, :development

# Require the engine file
require "easy_ml/engine"

Combustion.initialize! :all

# ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "easy_ml_test")

# ActiveRecord::Schema.define do
#   create_table :easy_ml_models do |t|
#     t.string :version
#     t.string :ml_model
#     t.string :task
#     t.json :metrics, default: []
#     t.json :file, null: false
#     t.timestamps
#   end
# end

require "rspec/rails"

PROJECT_ROOT = Pathname.new(File.expand_path("..", __dir__))
SPEC_ROOT = PROJECT_ROOT.join("spec")

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  config.filter_run_when_matching :focus

  config.before(:suite) do
    # Run your generator and apply the generated migration
    Rails::Generators.invoke("easy_ml:migration", [], { destination_root: Combustion::Application.root })

    # Ensure the correct migration paths are set
    migration_paths = ActiveRecord::Migrator.migrations_paths
    migration_paths << File.expand_path("internal/db/migrate", SPEC_ROOT)

    # Apply migrations based on Rails version
    case Rails::VERSION::MAJOR
    when 7
      ActiveRecord::MigrationContext.new(migration_paths).migrate
    when 6
      migration_context = ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration)
      migration_context.migrate
    else
      ActiveRecord::Migrator.migrate(migration_paths)
    end
  end

  config.use_transactional_fixtures = true
end
