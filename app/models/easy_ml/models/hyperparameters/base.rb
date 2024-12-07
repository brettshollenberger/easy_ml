module EasyML
  module Models
    module Hyperparameters
      class Base
        include GlueGun::DSL

        attribute :learning_rate, :float, default: 0.01
        attribute :max_iterations, :integer, default: 100
        attribute :batch_size, :integer, default: 32
        attribute :regularization, :float, default: 0.0001
        attribute :early_stopping_rounds

        def self.common_tree_params
          {
            learning_rate: {
              label: "Learning Rate",
              description: "Step size shrinkage used to prevent overfitting",
              min: 0.001,
              max: 1,
              step: 0.001
            },
            max_depth: {
              label: "Maximum Tree Depth",
              description: "Maximum depth of a tree",
              min: 1,
              max: 20,
              step: 1
            },
            n_estimators: {
              label: "Number of Trees",
              description: "Number of boosting rounds",
              min: 1,
              max: 1000,
              step: 1
            }
          }
        end

        def self.common_regularization_params
          {
            lambda: {
              label: "L2 Regularization",
              description: "L2 regularization term on weights",
              min: 0,
              max: 10,
              step: 0.1
            },
            alpha: {
              label: "L1 Regularization",
              description: "L1 regularization term on weights",
              min: 0,
              max: 10,
              step: 0.1
            }
          }
        end

        def to_h
          attributes.with_indifferent_access
        end

        def merge(other)
          return self if other.nil?

          other_hash = other.is_a?(Hyperparameters) ? other.to_h : other
          merged_hash = to_h.merge(other_hash)
          self.class.new(**merged_hash)
        end

        def [](key)
          send(key) if respond_to?(key)
        end

        def []=(key, value)
          send("#{key}=", value) if respond_to?("#{key}=")
        end
      end
    end
  end
end
