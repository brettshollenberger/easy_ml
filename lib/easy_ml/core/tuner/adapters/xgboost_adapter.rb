require_relative "base_adapter"

module EasyML
  module Core
    class Tuner
      module Adapters
        class XGBoostAdapter < BaseAdapter
          include GlueGun::DSL

          def defaults
            {
              learning_rate: {
                min: 0.001,
                max: 0.1,
                log: true
              },
              n_estimators: {
                min: 100,
                max: 1_000
              },
              max_depth: {
                min: 2,
                max: 20
              }
            }
          end

          def configure_callbacks
            wandb_callback = callbacks.detect { |h| h.keys.map(&:to_sym).include?(:wandb) }
            return unless wandb_callback.present?

            wandb_callback[:wandb][:project_name] = "#{project_name}_#{tune_started_at.strftime("%Y_%m_%d_%H_%M_%S")}"
            model.callbacks = callbacks
          end
        end
      end
    end
  end
end
