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
        end
      end
    end
  end
end
