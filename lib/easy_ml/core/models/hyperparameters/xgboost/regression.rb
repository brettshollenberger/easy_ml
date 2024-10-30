module EasyML
  module Models
    module Hyperparameters
      class XGBoost
        class Regression < XGBoost
          # Regression specific parameters
          attribute :colsample_bytree, :float, default: 1.0
          attribute :subsample, :float, default: 1.0

          validates :objective,
                    inclusion: { in: %w[reg:squarederror reg:logistic] }
        end
      end
    end
  end
end
