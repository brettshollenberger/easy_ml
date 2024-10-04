module EasyML
  module Models
    module Hyperparameters
      class XGBoost < EasyML::Hyperparameters
        define_attr :learning_rate, default: 0.1
        define_attr :max_depth, default: 6
        define_attr :n_estimators, default: 100
        define_attr :booster, default: "gbtree"
        define_attr :objective, default: "reg:squarederror"
      end
    end
  end
end
