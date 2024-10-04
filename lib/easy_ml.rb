# frozen_string_literal: true

require_relative "easy_ml/version"
require "glue_gun"

module EasyML
  class Error < StandardError; end

  require_relative "easy_ml/support"
  require_relative "easy_ml/logging"
  require_relative "easy_ml/data"
  require_relative "easy_ml/transforms"
  require_relative "easy_ml/models"
  require_relative "easy_ml/trainer"
end
