# frozen_string_literal: true

require "sprockets/railtie"
require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "resque/tasks"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[spec rubocop]

Bundler.require(:default)

# Load your gem's code
require_relative "lib/easy_ml"

# Load the annotate tasks
require "annotate/annotate_models"

task :environment do
  require "combustion"
  require "sprockets"
  Combustion.path = "spec/internal"
  Combustion.initialize! :active_record do |config|
    config.assets = ActiveSupport::OrderedOptions.new # Stub to avoid errors
    config.assets.enabled = false # Set false since assets are handled by Vite
  end
  EasyML::Engine.eager_load!
end

namespace :easy_ml do
  task annotate_models: :environment do
    model_dir = File.expand_path("app/models", EasyML::Engine.root)
    $LOAD_PATH.unshift(model_dir) unless $LOAD_PATH.include?(model_dir)

    AnnotateModels.do_annotations(
      is_rake: true,
      model_dir: [EasyML::Engine.root.join("app/models/easy_ml").to_s],
      root_dir: [EasyML::Engine.root.join("app/models/easy_ml").to_s],
      include_modules: true, # Include modules/namespaces in the annotation
    )
  end

  task :create_test_migrations do
    require "combustion"
    require "rails/generators"
    require_relative "lib/easy_ml/railtie/generators/migration/migration_generator"

    db_files = Dir.glob(EasyML::Engine.root.join("spec/internal/db/migrate/**/*"))

    FileUtils.rm(db_files)
    Rails::Generators.invoke("easy_ml:migration", [], { destination_root: EasyML::Engine.root.join("spec/internal") })
  end
end

task :environment do
  # Force the application to load (Rails or standalone app setup)
  require File.expand_path("config/environment", __dir__)
end

# Ensure resque:work depends on :environment
task "resque:work" => :environment
task "resque:workers" => :environment
