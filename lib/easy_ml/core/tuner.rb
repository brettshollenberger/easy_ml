require "optuna"
require_relative "tuner/adapters"

module EasyML
  module Core
    class Tuner
      attr_accessor :model, :dataset, :project_name, :task, :config,
                    :metrics, :objective, :n_trials, :direction, :evaluator,
                    :study, :results, :adapter

      def initialize(options = {})
        @model = options[:model]
        @dataset = options[:dataset]
        @project_name = options[:project_name]
        @task = options[:task]
        @config = options[:config] || {}
        @metrics = options[:metrics]
        @objective = options[:objective]
        @n_trials = options[:n_trials] || 100
        @direction = options[:direction] || "minimize"
        @evaluator = options[:evaluator]
        @adapter = initialize_adapter
      end

      def initialize_adapter
        case model&.model_type
        when "xgboost"
          Adapters::XGBoostAdapter.new(
            model: model,
            config: config,
            project_name: project_name,
            tune_started_at: nil,  # This will be set during tune
            y_true: nil, # This will be set during tune
          )
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
            hyperparameter_ranges: config,
          },
          direction: direction,
          status: :running,
          started_at: Time.current,
        )

        @study = Optuna::Study.new(direction: direction)
        @results = []
        model.evaluator = evaluator if evaluator.present?
        model.task = task
        model.dataset.refresh
        x_true, y_true = model.dataset.test(split_ys: true)
        tune_started_at = EasyML::Support::UTC.now
        adapter.tune_started_at = tune_started_at
        adapter.y_true = y_true
        adapter.x_true = x_true

        adapter.before_run

        model.prepare_data

        @study.optimize(n_trials: n_trials, callbacks: [method(:loggers)]) do |trial|
          puts "Running trial #{trial.number}"
          tuner_run = tuner_job.tuner_runs.new(
            trial_number: trial.number,
            status: :running,
          )

          begin
            run_metrics = tune_once(trial, x_true, y_true, adapter)
            adapter.after_iteration
            result = calculate_result(run_metrics)
            @results.push(result)

            tuner_run.update!(
              hyperparameters: model.hyperparameters.to_h,
              value: result,
              status: :success,
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
          status: :success,
          completed_at: Time.current,
        )

        best_run.hyperparameters
      rescue StandardError => e
        binding.pry
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
