require_relative "xgboost_core"
module EasyML
  module Core
    module Models
      class XGBoost < EasyML::Core::Model
        include XGBoostCore
      end
    end
  end
end
