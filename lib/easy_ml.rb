# frozen_string_literal: true

require "rails"
require "active_record"
require "active_model"
require "active_support/all"
require "numo/narray"
require "xgboost"
require "suo"
require "polars"
require_relative "easy_ml/version"
require_relative "easy_ml/engine"

module EasyML
  class Error < StandardError; end

  require_relative "easy_ml/configuration"
  require_relative "easy_ml/reasons"
  require_relative "easy_ml/deep_compact"
  require_relative "easy_ml/timing"
  require_relative "easy_ml/support"
  require_relative "easy_ml/core_ext"
  require_relative "easy_ml/logging"
  require_relative "easy_ml/data"
  require_relative "easy_ml/evaluators"
  require_relative "easy_ml/features"
  require_relative "easy_ml/feature_store"
  require_relative "easy_ml/core"
  require_relative "easy_ml/predict"
  require_relative "easy_ml/pending_migrations"
end
