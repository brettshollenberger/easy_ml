require "optuna"
require_relative "xgboost_adapter"

module EasyML
  module Core
    class Tuner
      class TunerRun
        include GlueGun::DSL

        attribute :model
        attribute :y_true
        attribute :config, :hash
        attribute :metrics, :array
        attribute :objective, :string

        dependency :adapter do |dep|
          dep.option :xgboost do |opt|
            opt.set_class XGBoostAdapter
            opt.bind_attribute :model
            opt.bind_attribute :config
          end

          dep.when do |_dep|
            case model
            when EasyML::Core::Models::XGBoost, EasyML::Models::XGBoost
              { option: :xgboost }
            end
          end
        end

        def tune(trial)
          self.config = deep_merge_defaults(config, adapter.defaults)
          adapter.run_trial(trial) do |model|
            y_pred = model.predict(y_true)
            model.metrics = metrics
            model.evaluate(y_pred: y_pred, y_true: y_true)
          end
        end

        def deep_merge_defaults(config, defaults)
          defaults.deep_merge(config) do |_key, default_value, config_value|
            if default_value.is_a?(Hash) && config_value.is_a?(Hash)
              default_value.merge(config_value)
            else
              config_value
            end
          end
        end
      end
    end
  end
end
