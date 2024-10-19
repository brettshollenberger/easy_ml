# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in easy_ml.gemspec
gemspec

gem "aws-sdk", "~> 3.1"
gem "glue_gun_dsl", "~> 0.1.20"
gem "rake", "~> 13.0"
gem "rubocop", "~> 1.21"
gem "wandb", path: "/Users/brettshollenberger/programming/wandb"
gem "xgb", "~> 0.9.0"

group :test do
  gem "activerecord"
  gem "combustion"
  gem "rspec", "~> 3.0"
  gem "rspec-rails"
  # gem "sqlite3", "~> 1.4"
  gem "database_cleaner-active_record"
  gem "pg"
  gem "timecop"
end
