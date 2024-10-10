# frozen_string_literal: true

require "bundler/setup"
require "timecop"
require "combustion"
Bundler.require :default, :development

# Require the engine file
require "easy_ml/engine"

# Initialize Combustion only for app directory specs
running_rails_specs = RSpec.configuration.files_to_run.any? { |file| file.include?("/app/") }
if running_rails_specs
  Combustion.initialize! :all
  require "rspec/rails"

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
end

PROJECT_ROOT = Pathname.new(File.expand_path("..", __dir__))
SPEC_ROOT = PROJECT_ROOT.join("spec")

# Load support files
Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  config.filter_run_when_matching :focus

  config.before(:each, :logsql) do
    ActiveRecord::Base.logger = Logger.new(STDOUT)
  end

  config.after(:each, :logsql) do
    ActiveRecord::Base.logger = nil
  end

  config.before(:suite) do
    if running_rails_specs && Dir.glob(Rails.root.join("db/migrate/**/*")).none?
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
  end

  # Configure CarrierWave storage based on environment variable or RSpec metadata
  config.before(:each) do |example|
    if example.metadata[:fog]
      CarrierWave.configure do |carrierwave_config|
        carrierwave_config.fog_credentials = {
          provider: "AWS",
          aws_access_key_id: "mock_access_key",
          aws_secret_access_key: "mock_secret_key",
          region: "us-east-1"
        }
        carrierwave_config.fog_directory = "mock-bucket"
      end
    else
      CarrierWave.configure do |carrierwave_config|
        carrierwave_config.storage = :file
        carrierwave_config.enable_processing = false
        carrierwave_config.root = "#{Rails.root.join("tmp")}"
      end
    end
  end

  if running_rails_specs
    config.before(:suite) do
      DatabaseCleaner.strategy = :truncation
      DatabaseCleaner.clean_with(:truncation)
    end

    config.around(:each) do |example|
      DatabaseCleaner.cleaning do
        example.run
      end
    end
  end
end
