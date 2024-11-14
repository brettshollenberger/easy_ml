# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in easy_ml.gemspec
gemspec

gem "annotate"
gem "awesome_print"
gem "aws-sdk", "~> 3.1"
gem "glue_gun_dsl", path: "/Users/brettshollenberger/programming/glue_gun_dsl" # "~> 0.1.34"
gem "inertia_rails", require: false
gem "jsonapi-serializer"
gem "numpy", "~> 0.4.0"
gem "pg"
gem "polars-df", ref: "203d16560e73b06a51d06cc66da141d0f5834060"
gem "rake", "~> 13.0"
gem "rubocop", "~> 1.21"
gem "sidekiq", "~> 6.5.6"
gem "sidekiq-batch"
gem "sidekiq-unique-jobs"
gem "suo"
gem "wandb", "~> 0.1.9"
gem "xgb", "~> 0.9.0"

group :test do
  gem "combustion"
  gem "database_cleaner-active_record"
  gem "rspec", "~> 3.0"
  gem "rspec-rails"
  gem "rspec-sidekiq"
  gem "timecop"
end
