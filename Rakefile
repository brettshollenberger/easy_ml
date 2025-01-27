# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[spec rubocop]

Bundler.require(:default)

# Load your gem's code
require_relative "lib/easy_ml"

# Load the annotate tasks
require "annotate/annotate_models"

require "combustion"
Combustion.path = "spec/internal"
Combustion::Application.configure_for_combustion
task :environment do
  Combustion::Application.initialize!

  # Reset migrations paths so we can keep the migrations in the project root,
  # not the Rails root
  migrations_paths = ["spec/internal/db/migrate"]
  ActiveRecord::Tasks::DatabaseTasks.migrations_paths = migrations_paths
  ActiveRecord::Migrator.migrations_paths = migrations_paths
end
Combustion::Application.load_tasks

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
