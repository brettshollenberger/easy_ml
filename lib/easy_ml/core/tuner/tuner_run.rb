require "optuna"
require_relative "adapters"

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
        attribute :callbacks, :array
        attribute :project_name, :string
        attribute :tune_started_at

        dependency :adapter do |dep|
          dep.option :xgboost do |opt|
            opt.set_class Adapters::XGBoostAdapter
            opt.bind_attribute :model
            opt.bind_attribute :config
            opt.bind_attribute :callbacks
            opt.bind_attribute :project_name
            opt.bind_attribute :tune_started_at
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
