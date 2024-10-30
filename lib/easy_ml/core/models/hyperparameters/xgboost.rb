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
      end
    end
  end
end

require_relative "xgboost/gbtree"
require_relative "xgboost/gblinear"
require_relative "xgboost/dart"
require_relative "xgboost/binary_classification"
require_relative "xgboost/multi_class"
require_relative "xgboost/regression"
