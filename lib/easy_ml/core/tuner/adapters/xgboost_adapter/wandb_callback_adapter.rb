module EasyML
  module Core
    class Tuner
      module Adapters
        class XGBoostAdapter < BaseAdapter
          class WandbCallbackAdapter
            attr_reader :model, :x_true, :y_true, :tune_started_at

            def initialize(model:, x_true:, y_true:, tune_started_at:)
              @model = model
              @x_true = x_true
              @y_true = y_true
              @tune_started_at = tune_started_at
            end

            def after_iteration(base_adapter)
              base_adapter.metadata[:wandb_url] = Wandb.current_run.url
            end

            def before_run(_base_adapter)
              wandb_callback = model.callbacks.detect { |cb| cb.class == Wandb::XGBoostCallback }
              return unless wandb_callback.present?

              project_name = "#{wandb_callback.project_name}_#{tune_started_at.strftime("%Y_%m_%d_%H_%M_%S")}"
              wandb_callback.project_name = project_name

              wandb_callback.custom_loggers = [
                lambda do |booster, _epoch, _hist|
                  dtrain = model.send(:preprocess, x_true, y_true)
                  y_pred = booster.predict(dtrain)

                  metrics = model.evaluate(y_pred: y_pred, y_true: y_true, x_true: x_true)
                  Wandb.log(metrics)
                end,
              ]
            end
          end
        end
      end
    end
  end
end
