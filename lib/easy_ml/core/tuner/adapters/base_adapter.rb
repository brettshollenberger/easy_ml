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
          attribute :callbacks, :array
          attribute :project_name, :string
          attribute :tune_started_at

          def run_trial(trial)
            suggest_parameters(trial)
            configure_callbacks
            model.fit
            yield model
          end

          def configure_callbacks
            raise "Subclasses fof Tuner::Adapter::BaseAdapter must define #configure_callbacks"
          end

          def suggest_parameters(trial)
            defaults.keys.each do |param_name|
              param_value = suggest_parameter(trial, param_name)
              model.hyperparameters.send("#{param_name}=", param_value)
            end
          end

          def suggest_parameter(trial, param_name)
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
