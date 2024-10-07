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

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/brettshollenberger/easy_ml"
  spec.metadata["changelog_uri"] = "https://github.com/brettshollenberger/easy_ml"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "activerecord"
  spec.add_runtime_dependency "activesupport"
  spec.add_runtime_dependency "carrierwave", "~> 2.0"
  spec.add_runtime_dependency "fog-aws", "~> 3.0"
  spec.add_runtime_dependency "glue_gun_dsl", "~> 0.1.10"
  spec.add_runtime_dependency "numo-narray"
  spec.add_runtime_dependency "polars-df"
  spec.add_runtime_dependency "rails"
  spec.add_runtime_dependency "xgb"

  # Uncomment to register a new dependency of your gem
  spec.add_development_dependency "appraisal"
  spec.add_development_dependency "combustion", "~> 1.3"
  spec.add_development_dependency "database_cleaner-active_record"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "ostruct"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "rspec", "~> 3.0"
end
