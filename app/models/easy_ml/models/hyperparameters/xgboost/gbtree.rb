module EasyML
  module Models
    module Hyperparameters
      class XGBoost
        class GBTree < XGBoost
          # Tree booster specific parameters
          attribute :gamma, :float, default: 0.0
          attribute :min_child_weight, :float, default: 1.0
          attribute :subsample, :float, default: 1.0
          attribute :colsample_bytree, :float, default: 1.0
          attribute :colsample_bylevel, :float, default: 1.0
          attribute :colsample_bynode, :float, default: 1.0
          attribute :tree_method, :string, default: "auto"
          attribute :scale_pos_weight, :float, default: 1.0 # For imbalanced classes

          validates :tree_method,
                    inclusion: { in: %w[auto exact approx hist gpu_hist] }

          def self.hyperparameter_constants
            Base.common_tree_params.merge(Base.common_regularization_params).merge(
              min_child_weight: {
                label: "Minimum Child Weight",
                description: "Minimum sum of instance weight needed in a child",
                min: 0,
                max: 10,
                step: 0.1
              },
              gamma: {
                label: "Gamma",
                description: "Minimum loss reduction required to make a further partition",
                min: 0,
                max: 10,
                step: 0.1
              },
              subsample: {
                label: "Subsample Ratio",
                description: "Subsample ratio of the training instances",
                min: 0.1,
                max: 1,
                step: 0.1
              },
              colsample_bytree: {
                label: "Column Sample by Tree",
                description: "Subsample ratio of columns when constructing each tree",
                min: 0.1,
                max: 1,
                step: 0.1
              },
              tree_method: {
                label: "Tree Construction Method",
                options: [
                  {
                    value: "auto",
                    label: "Auto",
                    description: "Use heuristic to choose the fastest method"
                  },
                  {
                    value: "exact",
                    label: "Exact",
                    description: "Exact greedy algorithm"
                  },
                  {
                    value: "approx",
                    label: "Approximate",
                    description: "Approximate greedy algorithm using sketching and histogram"
                  },
                  {
                    value: "hist",
                    label: "Histogram",
                    description: "Fast histogram optimized approximate greedy algorithm"
                  },
                  {
                    value: "gpu_hist",
                    label: "GPU Histogram",
                    description: "GPU implementation of hist algorithm"
                  }
                ]
              }
            )
          end
        end
      end
    end
  end
end
