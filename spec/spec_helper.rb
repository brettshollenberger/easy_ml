# frozen_string_literal: true

require "bundler/setup"
require "timecop"
require "benchmark"
require "resque"
require "active_job"
require "pry"
Bundler.require :default, :development

# Require the engine file
require "easy_ml/engine"

# Timing instrumentation
def log_time(label, &block)
  time = Benchmark.measure(&block)
  puts "#{label} took #{time.real.round(2)} seconds"
end

PROJECT_ROOT = Pathname.new(File.expand_path("..", __dir__))
SPEC_ROOT = PROJECT_ROOT.join("spec")

RSpec.configure do |config|
  include ActiveJob::TestHelper

  def require_rails_files
    require "combustion"
    # require "rails/generators"
    # Rails::Generators.invoke("easy_ml:migration", [], { destination_root: Combustion::Application.root })

    Combustion.initialize! :active_record do |config|
      config.assets = ActiveSupport::OrderedOptions.new
      config.assets.enabled = false
    end
    require "rspec/rails"

    # Convert Rails.root to Pathname to ensure consistent path handling
    Dir[Pathname.new(Rails.root).join("spec/support/**/*.rb").to_s].each { |f| require f }
  end

  # Only load Rails/Combustion for specs that need it
  any_rails_files = RSpec.configuration.files_to_run.any? { |file| file.include?("/app/") }
  if any_rails_files
    require_rails_files
  end

  config.before(:each) do
    clear_enqueued_jobs
    if any_rails_files
      EasyML::Cleaner.clean
    end
  end

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  config.filter_run_when_matching :focus

  config.before(:suite) do
    ActiveJob::Base.queue_adapter = :test
  end

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
    if any_rails_files
      EasyML::Configuration.configure do |config|
        config.storage = "s3"
        config.s3_bucket = "my-bucket"
        config.s3_access_key_id = "12345"
        config.s3_secret_access_key = "67890"
      end
    end
  end

  if ENV["RAILS_SPECS"] || RSpec.configuration.files_to_run.any? { |file| file.include?("/app/") }
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

EST = EasyML::Support::EST
UTC = EasyML::Support::UTC
