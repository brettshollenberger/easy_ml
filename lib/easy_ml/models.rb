module EasyML
  module Models
    require_relative "models/hyperparameters"
    require_relative "models/xgboost"

    AVAILABLE_MODELS = [XGBoost]
  end
end
