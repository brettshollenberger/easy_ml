# frozen_string_literal: true

require "bundler/setup"
require "timecop"
require "benchmark"
require "resque"
require "active_job"
require "pry"
require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "active_job/railtie"

Bundler.require :default, :development
ENV["S3_ACCESS_KEY_ID"] = "foo"
ENV["S3_SECRET_ACCESS_KEY"] = "bar"

# Timing instrumentation
def log_time(label, &block)
  time = Benchmark.measure(&block)
  puts "#{label} took #{time.real.round(2)} seconds"
end

PROJECT_ROOT = Pathname.new(File.expand_path("..", __dir__))
SPEC_ROOT = PROJECT_ROOT.join("spec")

RSpec.configure do |config|
  include ActiveJob::TestHelper
  @combustion_initialized = false

  def require_rails_files
    unless @combustion_initialized
      require "combustion"
      Combustion.initialize!
      @combustion_initialized = true
      require "rspec/rails"

      # Convert Rails.root to Pathname to ensure consistent path handling
      Dir[Pathname.new(Rails.root).join("spec/support/**/*.rb").to_s].each { |f| require f }
    end
  end

  # Only load Rails/Combustion for specs that need it
  any_rails_files = RSpec.configuration.files_to_run.any? { |file| file.include?("/app/") || file.include?("/requests/") }
  if any_rails_files
    require_rails_files
  end

  # Require the engine file
  # make sure this happens after require_rails_files
  require "easy_ml/engine"

  Dir.glob(EasyML::Engine.root.join("spec/internal/app/features/**/*.rb")).each do |file|
    require file
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
    if any_rails_files
      DatabaseCleaner.clean_with(:truncation)
      EasyML::Cleaner.clean
    end
  end

  config.before(:all) do
    if any_rails_files
      EasyML::Configuration.configure do |config|
        config.storage = "s3"
        config.s3_bucket = "my-bucket"
        config.s3_access_key_id = "12345"
        config.s3_secret_access_key = "67890"
        config.s3_region = "us-east-1"
      end
    end
  end

  config.before(:each) do
    mock_run = instance_double(Wandb::Run)
    allow(Wandb).to receive(:login).and_return(true)
    allow(Wandb).to receive(:init).and_return(true)
    allow(Wandb).to receive(:current_run).and_return(mock_run)
    allow(Wandb).to receive(:define_metric).and_return(true)
    allow(mock_run).to receive(:config=)
    allow(mock_run).to receive(:url).and_return("https://wandb.ai")
    allow(Wandb).to receive(:log)
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
