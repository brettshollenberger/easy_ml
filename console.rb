#!/usr/bin/env ruby
# frozen_string_literal: true

require "rubygems"
require "bundler/setup"

# Load necessary gems without automatically loading inertia_rails
Bundler.require :default, :development

# Load your engine and specific components
require_relative "lib/easy_ml"

# Load models only
Dir.glob(File.expand_path("app/models/easy_ml/**/*.rb", EasyML::Engine.root)).each do |file|
  require file
end

# Database setup if needed
db_config = YAML.load_file(File.expand_path("spec/internal/config/database.yml"))
ActiveRecord::Base.establish_connection(db_config["development"])
