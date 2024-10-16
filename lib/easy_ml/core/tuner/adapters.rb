module EasyML
  module Core
    class Tuner
      module Adapters
        require_relative "adapters/base_adapter"
        require_relative "adapters/xgboost_adapter"
      end
    end
  end
end
