module EasyML
  module Models
    module Hyperparameters
      class XGBoost
        class BinaryClassification < XGBoost
          attribute :scale_pos_weight, :float, default: 1.0
          attribute :colsample_bytree, :float, default: 1.0
          attribute :subsample, :float, default: 1.0

          validates :objective,
                    inclusion: { in: %w[binary:logistic binary:hinge] }
        end
      end
    end
  end
end
