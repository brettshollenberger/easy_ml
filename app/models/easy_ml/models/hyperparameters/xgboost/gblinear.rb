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
        end
      end
    end
  end
end
