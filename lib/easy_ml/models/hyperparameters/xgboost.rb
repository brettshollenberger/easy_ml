require "easy_ml/hyperparameters"

module EasyML
  module Models
    module Hyperparameters
      class XGBoost < EasyML::Hyperparameters
        include GlueGun::DSL

        attribute :learning_rate, :float, default: 0.1
        attribute :max_depth, :integer, default: 6
        attribute :n_estimators, :integer, default: 100
        attribute :booster, :string, default: "gbtree"
        attribute :objective, :string, default: "reg:squarederror"
      end
    end
  end
end
