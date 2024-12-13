module EasyML
  module Models
    module Hyperparameters
      class XGBoost
        class GBLinear < XGBoost
          attr_accessor :updater, :feature_selector, :lambda, :alpha

          def initialize(options = {})
            super
            @updater = options[:updater] || "shotgun"
            @feature_selector = options[:feature_selector] || "cyclic"
            @lambda = options[:lambda] || 1.0
            @alpha = options[:alpha] || 0.0
            validate!
          end

          def validate!
            unless %w[shotgun coord_descent].include?(@updater)
              raise ArgumentError, "Invalid updater: #{@updater}"
            end
            unless %w[cyclic shuffle greedy thrifty].include?(@feature_selector)
              raise ArgumentError, "Invalid feature_selector: #{@feature_selector}"
            end
          end

          def self.hyperparameter_constants
            # GBLinear only uses learning_rate from tree params
            { learning_rate: Base.common_tree_params[:learning_rate] }
              .merge(Base.common_regularization_params)
              .merge(
                feature_selector: {
                  label: "Feature Selector",
                  options: [
                    {
                      value: "cyclic",
                      label: "Cyclic",
                      description: "Update features in a cyclic order"
                    },
                    {
                      value: "shuffle",
                      label: "Shuffle",
                      description: "Update features in a random order"
                    },
                    {
                      value: "random",
                      label: "Random",
                      description: "Randomly select features to update"
                    },
                    {
                      value: "greedy",
                      label: "Greedy",
                      description: "Select features with the highest gradient magnitude"
                    },
                    {
                      value: "thrifty",
                      label: "Thrifty",
                      description: "Thrifty, approximated greedy algorithm"
                    }
                  ]
                },
                updater: {
                  label: "Updater",
                  options: [
                    {
                      value: "shotgun",
                      label: "Shotgun",
                      description: "Parallel coordinate descent algorithm"
                    },
                    {
                      value: "coord_descent",
                      label: "Coordinate Descent",
                      description: "Ordinary coordinate descent algorithm"
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
