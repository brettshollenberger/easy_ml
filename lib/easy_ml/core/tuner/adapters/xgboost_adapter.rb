require_relative "base_adapter"
require_relative "xgboost_adapter/wandb_callback_adapter"

module EasyML
  module Core
    class Tuner
      module Adapters
        class XGBoostAdapter < BaseAdapter
          register_callback_adapter Wandb::XGBoostCallback, WandbCallbackAdapter

          def defaults
            {
              learning_rate: {
                min: 0.001,
                max: 0.1,
                log: true,
              },
              n_estimators: {
                min: 100,
                max: 1_000,
              },
              max_depth: {
                min: 2,
                max: 20,
              },
            }
          end
        end
      end
    end
  end
end
