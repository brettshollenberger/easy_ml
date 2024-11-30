# frozen_string_literal: true

require "bundler/setup"
require "timecop"
require "combustion"
require "benchmark" # Add this to measure time
require "sidekiq/testing"
require "pry"
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

require "rails/generators"
Rails::Generators.invoke("easy_ml:migration", [], { destination_root: Combustion::Application.root })

Combustion.initialize! :active_record do |config|
  config.assets = ActiveSupport::OrderedOptions.new # Stub to avoid errors
  config.assets.enabled = false # Set false since assets are handled by Vite
end
require "rspec/rails"

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
      config.storage = "s3"
      config.s3_bucket = "my-bucket"
      config.s3_access_key_id = "12345"
      config.s3_secret_access_key = "67890"
    end
  end

  config.before(:each) do |_example|
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
# Sidekiq::Testing.fake!
Sidekiq::Testing.server_middleware do |chain|
  chain.add Sidekiq::Batch::Middleware::ServerMiddleware
end
EST = EasyML::Support::EST
UTC = EasyML::Support::UTC
