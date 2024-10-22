module EasyML
  module Core
    module Models
      require_relative "models/hyperparameters"
      require_relative "models/xgboost_service"

      AVAILABLE_MODELS = [XGBoostService]
    end
  end
end
