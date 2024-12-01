# frozen_string_literal: true

require_relative "lib/easy_ml/version"

Gem::Specification.new do |spec|
  spec.name = "easy_ml"
  spec.version = EasyML::VERSION
  spec.authors = ["Brett Shollenberger"]
  spec.email = ["brett.shollenberger@gmail.com"]

  spec.summary = "Effortless Machine Learning in Ruby"
  spec.description = "High level plug-and-play interface for composing Machine Learning applications"
  spec.homepage = "https://github.com/brettshollenberger/easy_ml"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/brettshollenberger/easy_ml"
  spec.metadata["changelog_uri"] = "https://github.com/brettshollenberger/easy_ml"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "activerecord"
  spec.add_runtime_dependency "activerecord-import", "~> 1.8.1"
  spec.add_runtime_dependency "activesupport"
  spec.add_runtime_dependency "awesome_print"
  spec.add_runtime_dependency "aws-sdk"
  # spec.add_runtime_dependency "glue_gun_dsl", "~> 0.1.34"
  #spec.add_runtime_dependency "historiographer", "~> 4.1.2"
  spec.add_runtime_dependency "inertia_rails"
  spec.add_runtime_dependency "jsonapi-serializer"
  spec.add_runtime_dependency "numo-narray"
  spec.add_runtime_dependency "numpy"
  spec.add_runtime_dependency "parallel"
  spec.add_runtime_dependency "polars-df", "~> 0.15.0"
  spec.add_runtime_dependency "pycall"
  spec.add_runtime_dependency "rails"
  spec.add_runtime_dependency "red-optuna"
  spec.add_runtime_dependency "sidekiq", "~> 6.5.6"
  spec.add_runtime_dependency "sidekiq-batch"
  spec.add_runtime_dependency "sidekiq-unique-jobs"
  spec.add_runtime_dependency "suo"
  spec.add_runtime_dependency "tailwindcss-rails"
  spec.add_runtime_dependency "vite_rails"
  spec.add_runtime_dependency "wandb", "~> 0.1.9"
  spec.add_runtime_dependency "xgb"

  spec.add_development_dependency "annotate"
  spec.add_development_dependency "appraisal"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "ostruct"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "sprockets-rails"
end
