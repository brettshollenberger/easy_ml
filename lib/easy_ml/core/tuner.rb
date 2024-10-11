require "optuna"
require_relative "tuner/tuner_run"
require_relative "tuner/xgboost_adapter"

module EasyML
  module Core
    class Tuner
      include GlueGun::DSL

      attribute :model
      attribute :dataset
      attribute :task, :string
      attribute :config, :hash
      attribute :metrics, :array
      attribute :objective, :string
      attribute :n_trials, default: 100
      attribute :run_metrics

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

      def loggers(_study, trial)
        return unless trial.state.name == "FAIL"

        raise "Trial failed: Stopping optimization."
      end

      def tune
        set_defaults!

        study = Optuna::Study.new
        _, y_true = model.dataset.test(split_ys: true)

        study.optimize(n_trials: n_trials, callbacks: [method(:loggers)]) do |trial|
          class << trial
            attr_accessor :run_metrics
          end
          config = self.config.clone

          if config.key?("models")
            model_name = trial.suggest_categorical("models", config["models"])
            trial_klass = EasyML::Core::Models.const_get(model_name)
            trial_klass.new(
              dataset: model.dataset || dataset
            )
            # Do additional setup for running through this...
          end

          model.task = task
          self.run_metrics = TunerRun.new(
            model: model,
            y_true: y_true,
            config: config,
            metrics: metrics,
            objective: objective
          ).tune(trial)

          run_metrics[objective.to_sym]
        rescue StandardError => e
          puts "Optuna failed with: #{e.message}"
        end
      end

      def set_defaults!
        unless task.present?
          self.task = model.task
          raise ArgumentError, "EasyML::Core::Tuner requires task (regression or classification)" unless task.present?
        end
        raise ArgumentError, "Objectives required for EasyML::Core::Tuner" unless objective.present?

        self.metrics = EasyML::Core::Model.new(task: task).allowed_metrics if metrics.nil? || metrics.empty?
      end
    end
  end
end
