module EasyML
  module Models
    module Hyperparameters
      class XGBoost
        class Dart < XGBoost
          # DART booster specific parameters
          attribute :rate_drop, :float, default: 0.0
          attribute :skip_drop, :float, default: 0.0
          attribute :sample_type, :string, default: "uniform"
          attribute :normalize_type, :string, default: "tree"
          attribute :subsample, :float, default: 1.0
          attribute :colsample_bytree, :float, default: 1.0

          validates :sample_type,
                    inclusion: { in: %w[uniform weighted] }
          validates :normalize_type,
                    inclusion: { in: %w[tree forest] }

          def self.hyperparameter_constants
            # DART uses all tree parameters since it's tree-based
            Base.common_tree_params.merge(Base.common_regularization_params).merge(
              rate_drop: {
                label: "Dropout Rate",
                description: "Dropout rate (a fraction of previous trees to drop)",
                min: 0,
                max: 1,
                step: 0.1
              },
              skip_drop: {
                label: "Skip Dropout",
                description: "Probability of skipping the dropout procedure during iteration",
                min: 0,
                max: 1,
                step: 0.1
              },
              sample_type: {
                label: "Sample Type",
                options: [
                  {
                    value: "uniform",
                    label: "Uniform",
                    description: "Dropped trees are selected uniformly"
                  },
                  {
                    value: "weighted",
                    label: "Weighted",
                    description: "Dropped trees are selected in proportion to weight"
                  }
                ]
              },
              normalize_type: {
                label: "Normalize Type",
                options: [
                  {
                    value: "tree",
                    label: "Tree",
                    description: "New trees have the same weight of dropped trees divided by k"
                  },
                  {
                    value: "forest",
                    label: "Forest",
                    description: "New trees have the same weight of sum of dropped trees"
                  }
                ]
              }
            ).merge(GBTree.hyperparameter_constants) # Include GBTree params since DART is tree-based
          end
        end
      end
    end
  end
end
