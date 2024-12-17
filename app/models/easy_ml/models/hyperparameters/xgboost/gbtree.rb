module EasyML
  module Models
    module Hyperparameters
      class XGBoost
        class GBTree < XGBoost
          attr_accessor :max_depth, :min_child_weight, :max_delta_step, :subsample,
                        :colsample_bytree, :colsample_bylevel, :colsample_bynode,
                        :tree_method, :gamma, :scale_pos_weight

          def initialize(options = {})
            super
            @max_depth = options[:max_depth] || 6
            @min_child_weight = options[:min_child_weight] || 1
            @max_delta_step = options[:max_delta_step] || 0
            @subsample = options[:subsample] || 1.0
            @colsample_bytree = options[:colsample_bytree] || 1.0
            @colsample_bylevel = options[:colsample_bylevel] || 1.0
            @colsample_bynode = options[:colsample_bynode] || 1.0
            @tree_method = options[:tree_method] || "auto"
            @gamma = options[:gamma] || 0.0
            @scale_pos_weight = options[:scale_pos_weight] || 1.0
            validate!
          end

          def validate!
            unless %w[auto exact approx hist gpu_hist].include?(@tree_method)
              raise ArgumentError, "Invalid tree_method: #{@tree_method}"
            end
          end

          def self.hyperparameter_constants
            Base.common_tree_params.merge(Base.common_regularization_params).merge(
              min_child_weight: {
                label: "Minimum Child Weight",
                description: "Minimum sum of instance weight needed in a child",
                min: 0,
                max: 10,
                step: 0.1,
              },
              gamma: {
                label: "Gamma",
                description: "Minimum loss reduction required to make a further partition",
                min: 0,
                max: 10,
                step: 0.1,
              },
              subsample: {
                label: "Subsample Ratio",
                description: "Subsample ratio of the training instances",
                min: 0.1,
                max: 1,
                step: 0.1,
              },
              colsample_bytree: {
                label: "Column Sample by Tree",
                description: "Subsample ratio of columns when constructing each tree",
                min: 0.1,
                max: 1,
                step: 0.1,
              },
              tree_method: {
                label: "Tree Construction Method",
                options: [
                  {
                    value: "auto",
                    label: "Auto",
                    description: "Use heuristic to choose the fastest method",
                  },
                  {
                    value: "exact",
                    label: "Exact",
                    description: "Exact greedy algorithm",
                  },
                  {
                    value: "approx",
                    label: "Approximate",
                    description: "Approximate greedy algorithm using sketching and histogram",
                  },
                  {
                    value: "hist",
                    label: "Histogram",
                    description: "Fast histogram optimized approximate greedy algorithm",
                  },
                  {
                    value: "gpu_hist",
                    label: "GPU Histogram",
                    description: "GPU implementation of hist algorithm",
                  },
                ],
              },
            )
          end
        end
      end
    end
  end
end
