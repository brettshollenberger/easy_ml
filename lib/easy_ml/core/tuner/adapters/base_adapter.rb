require_relative "callbacks"

module EasyML
  module Core
    class Tuner
      module Adapters
        class BaseAdapter
          include GlueGun::DSL
          include EasyML::Core::Tuner::Adapters::Callbacks

          attribute :config, :hash
          attribute :project_name, :string
          attribute :tune_started_at
          attribute :model
          attribute :x_true
          attribute :y_true
          attribute :metadata

          def before_run
            run_callbacks(:before_run)
          end

          def after_iteration
            run_callbacks(:after_iteration)
          end

          def after_run
            run_callbacks(:after_run)
          end

          def metadata
            @metadata ||= {}
            @metadata
          end

          def defaults
            {}
          end

          def run_trial(trial)
            config = deep_merge_defaults(self.config.clone.deep_symbolize_keys)
            suggest_parameters(trial, config)
            model.fit
            yield model
          end

          def suggest_parameters(trial, config)
            defaults.keys.inject({}) do |hash, param_name|
              hash.tap do
                param_value = suggest_parameter(trial, param_name, config)
                model.hyperparameters.send("#{param_name}=", param_value)
                hash[param_name] = param_value
              end
            end
          end

          def deep_merge_defaults(config)
            defaults.deep_symbolize_keys.deep_merge(config.deep_symbolize_keys) do |_key, default_value, config_value|
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
