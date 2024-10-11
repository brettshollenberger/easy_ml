module EasyML
  module Core
    class Tuner
      class XGBoostAdapter
        include GlueGun::DSL

        def defaults
          {
            learning_rate: {
              min: 0.001,
              max: 0.1,
              log: true
            }
          }
        end

        attribute :model
        attribute :config, :hash

        def run_trial(trial)
          learning_rate = suggest_parameter(trial, :learning_rate)

          model.hyperparameters.learning_rate = learning_rate
          model.fit
          yield model
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
