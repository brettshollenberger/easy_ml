require "numo/narray"
require_relative "evaluators/base_evaluator"
require_relative "evaluators/regression_evaluators"
require_relative "evaluators/classification_evaluators"

module EasyML
  module Core
    class ModelEvaluator
      class << self
        def callbacks=(callback)
          @callbacks ||= []
          @callbacks.push(callback)
        end

        def callbacks
          @callbacks || []
        end

        def register(metric_name, evaluator, type, aliases = [])
          @registry ||= {}
          metric_name = metric_name.to_s.split(" ").join("_").downcase.to_sym
          unless evaluator.included_modules.include?(Evaluators::BaseEvaluator)
            evaluator.include(Evaluators::BaseEvaluator)
          end

          callbacks.each do |callback|
            callback.call(metric_name)
          end

          @registry[metric_name.to_sym] = {
            evaluator: evaluator,
            type: type,
            aliases: (aliases || []).map(&:to_sym),
          }
        end

        def get(name)
          return if name.nil?

          @registry ||= {}
          option = (@registry[name.to_sym] || @registry.detect do |_k, opts|
            opts[:aliases].include?(name.to_sym)
          end.last) || {}
          option.dig(:evaluator)
        end

        def for_frontend(evaluator)
          evaluator.new.to_h
        end

        def default_evaluator(task)
          {
            classification: {
              metric: "accuracy_score",
              threshold: 0.70,
              direction: "maximize",
            },
            regression: {
              metric: "root_mean_squared_error",
              threshold: 10,
              direction: "minimize",
            },
          }[task.to_sym]
        end

        def metrics_by_task
          @registry.inject({}) do |hash, (k, v)|
            hash.tap do
              type = v[:type]
              unless type.is_a?(Array)
                type = [type]
              end

              type.each do |configuration|
                hash[configuration] ||= []
                hash[configuration] << v
              end
            end
          end.transform_values do |group|
            group.flat_map do |metric|
              for_frontend(metric.dig(:evaluator))
            end
          end
        end

        def metrics(task = nil)
          if task.nil?
            @registry.keys
          else
            @registry.select do |_k, v|
              case v[:type]
              when Array
                v[:type].map(&:to_sym).include?(task.to_sym)
              else
                v[:type].to_sym == task.to_sym
              end
            end.keys
          end
        end

        def evaluate(model:, y_pred:, y_true:, x_true: nil, evaluator: nil, dataset: nil)
          y_pred = normalize_input(y_pred)
          y_true = normalize_input(y_true)
          check_size(y_pred, y_true)

          metrics_results = {}

          if x_true.nil?
            x_true = model.dataset.test
          end

          if dataset.nil?
            dataset = model.dataset.test(all_columns: true)
          end

          model.metrics.each do |metric|
            evaluator_class = get(metric.to_sym)
            next unless evaluator_class

            evaluator_instance = evaluator_class.new

            metrics_results[metric.to_sym] = evaluator_instance.evaluate(
              y_pred: y_pred,
              y_true: y_true,
              x_true: x_true,
              dataset: dataset,
            )
          end

          if evaluator.present?
            evaluator = evaluator.symbolize_keys!
            evaluator_class = get(evaluator[:metric])
            raise "Unknown evaluator: #{evaluator}" unless evaluator_class

            evaluator_instance = evaluator_class.new
            response = evaluator_instance.evaluate(y_pred: y_pred, y_true: y_true, x_true: x_true, dataset: dataset)

            if response.is_a?(Hash)
              metrics_results.merge!(response)
            else
              metrics_results[evaluator[:metric].to_sym] = response
            end
          end

          metrics_results.symbolize_keys
        end

        private

        def check_size(y_pred, y_true)
          raise ArgumentError, "Different sizes" if y_true.size != y_pred.size
        end

        def normalize_input(input)
          case input
          when Polars::LazyFrame
            normalize_input(input.collect)
          when Array
            if input.first.class == TrueClass || input.first.class == FalseClass
              input = input.map { |value| value ? 1.0 : 0.0 }
            end
            Numo::DFloat.cast(input)
          when Polars::DataFrame
            if input.columns.count > 1
              raise ArgumentError, "Don't know how to evaluate input with multiple columns: #{input}"
            end

            normalize_input(input[input.columns.first])
          when Polars::Series
            if input.dtype == Polars::Boolean
              input = input.cast(Polars::Int64)
            end
            Numo::DFloat.cast(input)
          else
            raise ArgumentError, "Don't know how to evaluate model with y_pred type #{input.class}"
          end
        end
      end
    end
  end
end

# Register default evaluators
EasyML::Core::ModelEvaluator.register(
  :mean_absolute_error,
  EasyML::Core::Evaluators::RegressionEvaluators::MeanAbsoluteError,
  :regression,
  %w[mae]
)
EasyML::Core::ModelEvaluator.register(
  :mean_squared_error,
  EasyML::Core::Evaluators::RegressionEvaluators::MeanSquaredError,
  :regression,
  %w[mse]
)
EasyML::Core::ModelEvaluator.register(
  :root_mean_squared_error,
  EasyML::Core::Evaluators::RegressionEvaluators::RootMeanSquaredError,
  :regression,
  %w[rmse]
)

EasyML::Core::ModelEvaluator.register(
  :r2_score,
  EasyML::Core::Evaluators::RegressionEvaluators::R2Score,
  :regression,
  %w[r2]
)
EasyML::Core::ModelEvaluator.register(
  :accuracy_score,
  EasyML::Core::Evaluators::ClassificationEvaluators::AccuracyScore,
  :classification,
  %w[accuracy]
)
EasyML::Core::ModelEvaluator.register(
  :precision_score,
  EasyML::Core::Evaluators::ClassificationEvaluators::PrecisionScore,
  :classification,
  %w[precision]
)
EasyML::Core::ModelEvaluator.register(
  :recall_score,
  EasyML::Core::Evaluators::ClassificationEvaluators::RecallScore,
  :classification,
  %w[recall]
)
EasyML::Core::ModelEvaluator.register(
  :f1_score,
  EasyML::Core::Evaluators::ClassificationEvaluators::F1Score,
  :classification,
  %w[f1]
)
# EasyML::Core::ModelEvaluator.register(
#   :auc,
#   EasyML::Core::Evaluators::ClassificationEvaluators::AUC,
#   :classification,
#   %w[auc]
# )
# EasyML::Core::ModelEvaluator.register(
#   :roc_auc,
#   EasyML::Core::Evaluators::ClassificationEvaluators::ROC_AUC,
#   :classification,
#   %w[roc_auc]
# )
