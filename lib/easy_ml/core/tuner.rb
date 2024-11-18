require "optuna"
require_relative "tuner/adapters"

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
      attribute :direction, default: "minimize"
      attribute :evaluator
      attr_accessor :study, :results

      dependency :adapter, lazy: true do |dep|
        dep.option :xgboost do |opt|
          opt.set_class Adapters::XGBoostAdapter
          opt.bind_attribute :model
          opt.bind_attribute :config
          opt.bind_attribute :project_name
          opt.bind_attribute :tune_started_at
          opt.bind_attribute :y_true
        end

        dep.when do |_dep|
          case model
          when EasyML::Core::Models::XGBoost
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

        tuner_job = EasyML::TunerJob.create!(
          model: model,
          config: {
            n_trials: n_trials,
            objective: objective,
            hyperparameter_ranges: config
          },
          direction: direction,
          status: :running,
          started_at: Time.current
        )

        @study = Optuna::Study.new(direction: direction)
        @results = []
        model.evaluator = evaluator if evaluator.present?
        model.task = task
        model.dataset.refresh
        x_true, y_true = model.dataset.test(split_ys: true)
        tune_started_at = UTC.now
        adapter = adapter_class.new(
          model: model,
          config: config,
          tune_started_at: tune_started_at,
          y_true: y_true,
          x_true: x_true
        )

        adapter.before_run

        model.prepare_data

        @study.optimize(n_trials: n_trials, callbacks: [method(:loggers)]) do |trial|
          tuner_run = tuner_job.tuner_runs.new(
            trial_number: trial.number,
            status: :running
          )

          begin
            run_metrics = tune_once(trial, x_true, y_true, adapter)
            adapter.after_iteration
            result = calculate_result(run_metrics)
            @results.push(result)

            tuner_run.update!(
              hyperparameters: model.hyperparameters.to_h,
              value: result,
              status: :completed
            )

            result
          rescue StandardError => e
            tuner_run.update!(status: :failed)
            puts "Optuna failed with: #{e.message}"
          end
        end

        return nil if tuner_job.tuner_runs.all?(&:failed?)

        best_run = tuner_job.best_run
        adapter.after_run
        tuner_job.update!(
          metadata: adapter.metadata,
          best_tuner_run_id: best_run.id,
          status: :completed,
          completed_at: Time.current
        )

        best_run.hyperparameters
      rescue StandardError => e
        tuner_job&.update!(status: :failed, completed_at: Time.current)
        raise e
      end

      private

      def calculate_result(run_metrics)
        if model.evaluator.present?
          run_metrics[model.evaluator[:metric]]
        else
          run_metrics[objective.to_sym]
        end
      end

      def adapter_class
        case model.model_type
        when "EasyML::Models::XGBoost"
          Adapters::XGBoostAdapter
        end
      end

      def tune_once(trial, x_true, y_true, adapter)
        adapter.run_trial(trial) do |model|
          y_pred = model.predict(x_true)
          model.metrics = metrics
          model.evaluate(y_pred: y_pred, y_true: y_true, x_true: x_true)
        end
      end

      def set_defaults!
        unless task.present?
          self.task = model.task
          raise ArgumentError, "EasyML::Core::Tuner requires task (regression or classification)" unless task.present?
        end
        raise ArgumentError, "Objectives required for EasyML::Core::Tuner" unless objective.present?

        self.metrics = EasyML::Model.new(task: task).allowed_metrics if metrics.nil? || metrics.empty?
      end
    end
  end
end
