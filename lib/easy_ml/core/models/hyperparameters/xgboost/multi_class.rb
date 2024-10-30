module EasyML
  module Models
    module Hyperparameters
      class XGBoost
        class MultiClass < XGBoost
          # Multi-class specific parameters
          attribute :num_class, :integer, default: 3
          attribute :colsample_bytree, :float, default: 1.0
          attribute :subsample, :float, default: 1.0

          validates :objective,
                    inclusion: { in: %w[multi:softmax multi:softprob] }
          validates :num_class,
                    numericality: { greater_than_or_equal_to: 2 }
        end
      end
    end
  end
end
