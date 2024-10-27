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

namespace :easy_ml do
  task :annotate_models do
    db_config = YAML.load_file(
      File.expand_path("spec/internal/config/database.yml")
    )
    ActiveRecord::Base.establish_connection(db_config["test"])

    model_dir = File.expand_path("app/models", EasyML::Engine.root)
    $LOAD_PATH.unshift(model_dir) unless $LOAD_PATH.include?(model_dir)

    Dir.glob(
      File.expand_path("app/models/easy_ml/**/*.rb", EasyML::Engine.root)
    ).each do |file|
      require file
    end

    AnnotateModels.do_annotations(
      is_rake: true,
      model_dir: ["app/models/easy_ml"]
    )
  end
end
