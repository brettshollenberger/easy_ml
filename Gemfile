# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in easy_ml.gemspec
gemspec

gem "annotate"
gem "awesome_print"
gem "aws-sdk", "~> 3.1"
gem "glue_gun_dsl", path: "/Users/brettshollenberger/programming/glue_gun_dsl"
gem "rake", "~> 13.0"
gem "rubocop", "~> 1.21"
gem "sidekiq"
gem "wandb", "~> 0.1.8"
gem "xgb", "~> 0.9.0"

group :development, :test do
  gem "combustion"
  gem "database_cleaner-active_record"
  gem "factory_bot_rails"
  gem "pg"
  gem "rspec-rails"
end

group :test do
  gem "timecop"
end
