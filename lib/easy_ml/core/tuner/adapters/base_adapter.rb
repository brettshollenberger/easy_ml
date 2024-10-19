module EasyML
  module Core
    class Tuner
      module Adapters
        class BaseAdapter
          include GlueGun::DSL

          def defaults
            {}
          end

          attribute :model
          attribute :config, :hash
          attribute :project_name, :string
          attribute :tune_started_at
          attribute :y_true
          attribute :x_true

          def run_trial(trial, train, valid)
            config = deep_merge_defaults(self.config.clone)
            suggest_parameters(trial, config)
            model.fit(d_train: train, d_valid: valid)
            yield model
          end

          def configure_callbacks
            raise "Subclasses fof Tuner::Adapter::BaseAdapter must define #configure_callbacks"
          end

          def suggest_parameters(trial, config)
            defaults.keys.each do |param_name|
              param_value = suggest_parameter(trial, param_name, config)
              model.hyperparameters.send("#{param_name}=", param_value)
            end
          end

          def deep_merge_defaults(config)
            defaults.deep_merge(config) do |_key, default_value, config_value|
              if default_value.is_a?(Hash) && config_value.is_a?(Hash)
                default_value.merge(config_value)
              else
                config_value
              end
            end
          end

          def suggest_parameter(trial, param_name, config)
            param_config = config[param_name]
            min = param_config[:min]
            max = param_config[:max]
            log = param_config[:log]

            if log
              trial.suggest_loguniform(param_name.to_s, min, max)
            else
              trial.suggest_uniform(param_name.to_s, min, max)
            end
          end
        end
      end
    end
  end
end
