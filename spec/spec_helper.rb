# frozen_string_literal: true

require "bundler/setup"
require "timecop"
require "combustion"
require "benchmark" # Add this to measure time
require "sidekiq/testing"
Bundler.require :default, :development

# Require the engine file
require "easy_ml/engine"

# Timing instrumentation
def log_time(label, &block)
  time = Benchmark.measure(&block)
  puts "#{label} took #{time.real.round(2)} seconds"
end

# Initialize Combustion only for app directory specs
running_rails_specs = RSpec.configuration.files_to_run.any? { |file| file.include?("/app/") }
PROJECT_ROOT = Pathname.new(File.expand_path("..", __dir__))
SPEC_ROOT = PROJECT_ROOT.join("spec")

if running_rails_specs
  Combustion.initialize! :active_record
  require "rspec/rails"

  if Dir.glob(Rails.root.join("db/migrate/**/*")).none?
    Rails::Generators.invoke("easy_ml:migration", [], { destination_root: Combustion::Application.root })

    migration_paths = ActiveRecord::Migrator.migrations_paths
    migration_paths << File.expand_path("internal/db/migrate", SPEC_ROOT)

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

Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

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

  config.after(:suite) do
    FileUtils.rm_rf(Rails.root.join("tmp/"))
  end

  config.before(:all) do
    EasyML::Configuration.configure do |config|
      config.s3_bucket = "my-bucket"
    end
  end

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

    Sidekiq::Worker.clear_all
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

# Enable fake mode for Sidekiq testing
Sidekiq::Testing.fake!
