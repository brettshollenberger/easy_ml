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

          def prepare_data
            puts "Fetching train"
            x_train, y_train = model.dataset.train(split_ys: true)
            puts "Fetching valid"
            x_valid, y_valid = model.dataset.valid(split_ys: true)
            puts "Preprocessing train..."
            d_train = model.send(:preprocess, x_train, y_train)
            puts "Preprocessing valid..."
            d_valid = model.send(:preprocess, x_valid, y_valid)
            [d_train, d_valid]
          end

          def configure_callbacks
            model.customize_callbacks do |callbacks|
              return unless callbacks.present?

              wandb_callback = callbacks.detect { |cb| cb.class == Wandb::XGBoostCallback }
              return unless wandb_callback.present?

              wandb_callback.project_name = "#{wandb_callback.project_name}_#{tune_started_at.strftime("%Y_%m_%d_%H_%M_%S")}"
              wandb_callback.custom_loggers = [
                lambda do |booster, _epoch, _hist|
                  dtrain = model.send(:preprocess, x_true, y_true)
                  y_pred = booster.predict(dtrain)
                  metrics = model.evaluate(y_pred: y_pred, y_true: y_true, x_true: x_true)
                  Wandb.log(metrics)
                end
              ]
            end
          end
        end
      end
    end
  end
end
