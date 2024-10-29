#!/usr/bin/env ruby
# frozen_string_literal: true

require "rubygems"
require "bundler/setup"

Bundler.require :default, :development
require_relative "lib/easy_ml"

Dir.glob(File.expand_path("app/models/easy_ml/**/*.rb", EasyML::Engine.root)).each do |file|
  require file
end

db_config = YAML.load_file(File.expand_path("spec/internal/config/database.yml"))

# Establish ActiveRecord connection
ActiveRecord::Base.establish_connection(db_config["development"])
