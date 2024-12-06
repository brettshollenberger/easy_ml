module EasyML
  module Models
    module Hyperparameters
      class XGBoost
        class GBLinear < XGBoost
          # Linear booster specific parameters
          attribute :updater, :string, default: "shotgun"
          attribute :feature_selector, :string, default: "cyclic"
          attribute :lambda, :float, default: 1.0
          attribute :alpha, :float, default: 0.0

          validates :updater,
                    inclusion: { in: %w[shotgun coord_descent] }
          validates :feature_selector,
                    inclusion: { in: %w[cyclic shuffle greedy thrifty] }

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
