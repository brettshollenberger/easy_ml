module EasyML
  module Models
    module Hyperparameters
      class XGBoost
        class Dart < XGBoost
          attr_accessor :rate_drop, :skip_drop, :sample_type, :normalize_type,
                        :subsample, :colsample_bytree

          def initialize(options = {})
            super
            @rate_drop = options[:rate_drop] || 0.0
            @skip_drop = options[:skip_drop] || 0.0
            @sample_type = options[:sample_type] || "uniform"
            @normalize_type = options[:normalize_type] || "tree"
            @subsample = options[:subsample] || 1.0
            @colsample_bytree = options[:colsample_bytree] || 1.0
            validate!
          end

          def validate!
            unless %w[uniform weighted].include?(@sample_type)
              raise ArgumentError, "Invalid sample_type: #{@sample_type}"
            end
            unless %w[tree forest].include?(@normalize_type)
              raise ArgumentError, "Invalid normalize_type: #{@normalize_type}"
            end
          end

          def self.hyperparameter_constants
            # DART uses all tree parameters since it's tree-based
            Base.common_tree_params.merge(Base.common_regularization_params).merge(
              rate_drop: {
                label: "Dropout Rate",
                description: "Dropout rate (a fraction of previous trees to drop)",
                min: 0,
                max: 1,
                step: 0.1,
              },
              skip_drop: {
                label: "Skip Dropout",
                description: "Probability of skipping the dropout procedure during iteration",
                min: 0,
                max: 1,
                step: 0.1,
              },
              sample_type: {
                label: "Sample Type",
                options: [
                  {
                    value: "uniform",
                    label: "Uniform",
                    description: "Dropped trees are selected uniformly",
                  },
                  {
                    value: "weighted",
                    label: "Weighted",
                    description: "Dropped trees are selected in proportion to weight",
                  },
                ],
              },
              normalize_type: {
                label: "Normalize Type",
                options: [
                  {
                    value: "tree",
                    label: "Tree",
                    description: "New trees have the same weight of dropped trees divided by k",
                  },
                  {
                    value: "forest",
                    label: "Forest",
                    description: "New trees have the same weight of sum of dropped trees",
                  },
                ],
              },
            ).merge(GBTree.hyperparameter_constants) # Include GBTree params since DART is tree-based
          end
        end
      end
    end
  end
end
