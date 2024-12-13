module EasyML
  module Models
    module Hyperparameters
      class XGBoost < Base
        attr_accessor :learning_rate, :max_depth, :n_estimators, :booster,
                      :objective, :lambda, :alpha

        VALID_OBJECTIVES = %w[binary:logistic binary:hinge multi:softmax multi:softprob reg:squarederror reg:logistic].freeze
        VALID_BOOSTERS = %w[gbtree gblinear dart].freeze

        def initialize(options = {})
          super
          @learning_rate = options[:learning_rate] || 0.1
          @max_depth = options[:max_depth] || 6
          @n_estimators = options[:n_estimators] || 100
          @booster = options[:booster] || "gbtree"
          @objective = options[:objective] || "reg:squarederror"
          @lambda = options[:lambda] || 1.0
          @alpha = options[:alpha] || 0.0
          validate! if self.class.name == "EasyML::Models::Hyperparameters::XGBoost"
        end

        def validate!
          unless VALID_OBJECTIVES.include?(@objective)
            raise ArgumentError, "Invalid objective. Must be one of: #{VALID_OBJECTIVES.join(", ")}"
          end
          unless VALID_BOOSTERS.include?(@booster)
            raise ArgumentError, "Invalid booster. Must be one of: #{VALID_BOOSTERS.join(", ")}"
          end
        end

        def to_h
          super.merge(
            learning_rate: @learning_rate,
            max_depth: @max_depth,
            n_estimators: @n_estimators,
            booster: @booster,
            objective: @objective,
            lambda: @lambda,
            alpha: @alpha,
          )
        end

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
