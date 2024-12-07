module EasyML
  module Models
    module Hyperparameters
      class XGBoost < Base
        include GlueGun::DSL

        # Core parameters
        attribute :learning_rate, :float, default: 0.1
        attribute :max_depth, :integer, default: 6
        attribute :n_estimators, :integer, default: 100
        attribute :booster, :string, default: "gbtree"
        attribute :objective, :string, default: "reg:squarederror"
        attribute :lambda, :float, default: 1.0   # L2 regularization
        attribute :alpha, :float, default: 0.0    # L1 regularization

        validates :objective,
                  inclusion: { in: %w[binary:logistic binary:hinge multi:softmax multi:softprob reg:squarederror
                                     reg:logistic] }
        validates :booster,
                  inclusion: { in: %w[gbtree gblinear dart] }

        def self.hyperparameter_constants
          {
            booster: {
              label: "XGBoost Booster",
              options: [
                {
                  value: "gbtree",
                  label: "Gradient Boosted Tree",
                  description: "Traditional Gradient Boosting Decision Tree",
                },
                {
                  value: "gblinear",
                  label: "Gradient Boosted Linear",
                  description: "Generalized Linear Model with gradient boosting",
                },
                {
                  value: "dart",
                  label: "DART",
                  description: "Dropouts meet Multiple Additive Regression Trees",
                },
              ],
            },
            hyperparameters: {
              depends_on: "booster",
              gbtree: GBTree.hyperparameter_constants,
              gblinear: GBLinear.hyperparameter_constants,
              dart: Dart.hyperparameter_constants,
            },
          }
        end
      end
    end
  end
end

require_relative "xgboost/gbtree"
require_relative "xgboost/gblinear"
require_relative "xgboost/dart"
