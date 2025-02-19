module EasyML
  module Core
    class Tuner
      module Adapters
        class BaseAdapter
          attr_accessor :config, :project_name, :tune_started_at, :model,
                        :x_valid, :y_valid, :metadata, :model

          def initialize(options = {})
            @model = options[:model]
            @config = options[:config] || {}
            @project_name = options[:project_name]
            @tune_started_at = options[:tune_started_at]
            @model = options[:model]
            @x_valid = options[:x_valid]
            @y_valid = options[:y_valid]
            @metadata = options[:metadata] || {}
          end

          def defaults
            model.adapter.hyperparameters.class.hyperparameter_constants.transform_values do |constant|
              values = constant.slice(:min, :max, :step, :options)
              if values.key?(:options)
                values[:options] = values[:options].map { |option| option[:value] }
              end
              values
            end
          end

          def run_trial(trial)
            config = deep_merge_defaults(self.config.clone.deep_symbolize_keys)
            # For first trial, re-use the original hyperparameters, so they
            # serve as our starting point/imputers
            unless trial == 1
              suggest_parameters(trial, config)
            end
            yield model
          end

          def suggest_parameters(trial, config)
            config.keys.inject({}) do |hash, param_name|
              hash.tap do
                param_value = suggest_parameter(trial, param_name, config)
                puts "Suggesting #{param_name}: #{param_value}"
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
            if !param_config.is_a?(Hash)
              return param_config
            end

            min = param_config[:min]
            max = param_config[:max]
            log = param_config[:log]
            options = param_config[:options]

            if options
              trial.suggest_categorical(param_name.to_s, options)
            elsif log
              trial.suggest_loguniform(param_name.to_s, min, max)
            elsif max.is_a?(Integer) && min.is_a?(Integer)
              trial.suggest_int(param_name.to_s, min, max)
            else
              trial.suggest_uniform(param_name.to_s, min, max)
            end
          end
        end
      end
    end
  end
end
