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
        end
      end
    end
  end
end
