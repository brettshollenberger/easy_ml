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
      attr_accessor :study, :results

      dependency :adapter, lazy: false do |dep|
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

        @study = Optuna::Study.new
        @results = []
        model.task = task
        x_true, y_true = model.dataset.test(split_ys: true)
        tune_started_at = EST.now
        adapter = pick_adapter.new(model: model, config: config, tune_started_at: tune_started_at, y_true: y_true,
                                   x_true: x_true)
        adapter.configure_callbacks
        puts "Preparing data..."
        train, valid = adapter.prepare_data
        puts "Running tuner"

        @study.optimize(n_trials: n_trials, callbacks: [method(:loggers)]) do |trial|
          run_metrics = tune_once(trial, train, valid, x_true, y_true, adapter)

          result = if model.evaluator.present?
                     if model.evaluator_metric.present?
                       run_metrics[model.evaluator_metric]
                     else
                       run_metrics[:custom]
                     end
                   else
                     run_metrics[objective.to_sym]
                   end
          @results.push(result)
          result
        rescue StandardError => e
          puts "Optuna failed with: #{e.message}"
        end

        raise "Optuna study failed" unless @study.respond_to?(:best_trial)

        @study.best_trial.params
      end

      def pick_adapter
        case model
        when EasyML::Core::Models::XGBoost, EasyML::Models::XGBoost
          Adapters::XGBoostAdapter
        end
      end

      def tune_once(trial, train, valid, x_true, y_true, adapter)
        adapter.run_trial(trial, train, valid) do |model|
          y_pred = model.predict(y_true)
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

        self.metrics = EasyML::Core::Model.new(task: task).allowed_metrics if metrics.nil? || metrics.empty?
      end
    end
  end
end
