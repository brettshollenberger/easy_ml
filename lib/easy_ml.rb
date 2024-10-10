# frozen_string_literal: true

require "rails"
require "active_record"
require "active_model"
require "glue_gun"
require "numo/narray"
require "xgboost"
require_relative "easy_ml/version"
require_relative "easy_ml/engine"

module EasyML
  class Error < StandardError; end

  require_relative "easy_ml/support"
  require_relative "easy_ml/core_ext"
  require_relative "easy_ml/logging"
  require_relative "easy_ml/data"
  require_relative "easy_ml/transforms"
  require_relative "easy_ml/core"
  require_relative "easy_ml/trainer"
end
