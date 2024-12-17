require "optuna"
require_relative "tuner/adapters"

module EasyML
  module Core
    class Tuner
      attr_accessor :model, :dataset, :project_name, :task, :config,
                    :metrics, :objective, :n_trials, :direction, :evaluator,
                    :study, :results, :adapter, :tune_started_at, :x_true, :y_true,
                    :project_name, :job, :current_run

      def initialize(options = {})
        @model = options[:model]
        @dataset = options[:dataset]
        @project_name = options[:project_name]
        @task = options[:task]
        @config = options[:config] || {}
        @metrics = options[:metrics]
        @objective = options[:objective]
        @n_trials = options[:n_trials] || 100
        @direction = EasyML::Core::ModelEvaluator.get(objective).new.direction
        @evaluator = options[:evaluator]
        @tune_started_at = EasyML::Support::UTC.now
        @project_name = "#{model.name}_#{tune_started_at.strftime("%Y_%m_%d_%H_%M_%S")}"
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

      def wandb_enabled?
        EasyML::Configuration.wandb_api_key.present?
      end

      def tune(&progress_block)
        set_defaults!
        @adapter = initialize_adapter

        tuner_params = {
          model: model,
          config: {
            n_trials: n_trials,
            objective: objective,
            hyperparameter_ranges: config,
          },
          direction: direction,
          status: :running,
          started_at: Time.current,
          wandb_url: wandb_enabled? ? "https://wandb.ai/fundera/#{@project_name}" : nil,
        }.compact

        tuner_job = EasyML::TunerJob.create!(tuner_params)
        @job = tuner_job
        @study = Optuna::Study.new(direction: direction)
        @results = []
        model.evaluator = evaluator if evaluator.present?
        model.task = task

        model.dataset.refresh
        x_true, y_true = model.dataset.test(split_ys: true)
        self.x_true = x_true
        self.y_true = y_true
        adapter.tune_started_at = tune_started_at
        adapter.y_true = y_true
        adapter.x_true = x_true

        model.prepare_data unless model.batch_mode
        model.prepare_callbacks(self)

        n_trials.times do |run_number|
          trial = @study.ask
          puts "Running trial #{trial.number}"
          @tuner_run = tuner_job.tuner_runs.new(
            trial_number: trial.number,
            status: :running,
          )

          self.current_run = @tuner_run

          begin
            run_metrics = tune_once(trial, x_true, y_true, adapter, &progress_block)
            result = calculate_result(run_metrics)
            @results.push(result)

            params = {
              hyperparameters: model.hyperparameters.to_h,
              value: result,
              status: :success,
            }.compact

            @tuner_run.update!(params)
            @study.tell(trial, result)
          rescue StandardError => e
            @tuner_run.update!(status: :failed, hyperparameters: {})
            puts "Optuna failed with: #{e.message}"
            raise e
          end
        end

        model.after_tuning
        return nil if tuner_job.tuner_runs.all?(&:failed?)

        best_run = tuner_job.best_run
        tuner_job.update!(
          metadata: adapter.metadata,
          best_tuner_run_id: best_run&.id,
          status: :success,
          completed_at: Time.current,
        )

        best_run&.hyperparameters
      rescue StandardError => e
        tuner_job&.update!(status: :failed, completed_at: Time.current)
        raise e
      end

      private

      def calculate_result(run_metrics)
        run_metrics.symbolize_keys!

        if model.evaluator.present?
          run_metrics[model.evaluator[:metric].to_sym]
        else
          run_metrics[objective.to_sym]
        end
      end

      def tune_once(trial, x_true, y_true, adapter, &progress_block)
        adapter.run_trial(trial) do |model|
          model.fit(tuning: true, &progress_block)
          y_pred = model.predict(x_true)
          model.metrics = metrics
          metrics = model.evaluate(y_pred: y_pred, y_true: y_true, x_true: x_true)
          puts metrics
          metrics
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
