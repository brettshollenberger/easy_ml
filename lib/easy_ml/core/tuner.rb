require "optuna"
require_relative "tuner/tuner_run"

module EasyML
  module Core
    class Tuner
      include GlueGun::DSL

      attribute :model
      attribute :dataset
      attribute :project_name, :string
      attribute :task, :string
      attribute :config, :hash, default: {}
      attribute :metrics, :array
      attribute :objective, :string
      attribute :n_trials, default: 100
      attribute :run_metrics
      attribute :callbacks, :array

      def loggers(_study, trial)
        return unless trial.state.name == "FAIL"

        raise "Trial failed: Stopping optimization."
      end

      def tune
        set_defaults!

        study = Optuna::Study.new
        _, y_true = model.dataset.test(split_ys: true)
        tune_started_at = EST.now

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
            objective: objective,
            tune_started_at: tune_started_at,
            project_name: project_name,
            callbacks: callbacks
          ).tune(trial)

          run_metrics[objective.to_sym]
        rescue StandardError => e
          puts "Optuna failed with: #{e.message}"
        end

        raise "Optuna study failed" unless study.respond_to?(:best_trial)

        study.best_trial.params
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
