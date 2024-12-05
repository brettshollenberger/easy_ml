require "numo/narray"
require_relative "evaluators/base_evaluator"
require_relative "evaluators/regression_evaluators"
require_relative "evaluators/classification_evaluators"

module EasyML
  module Core
    class ModelEvaluator
      class << self
        def register(metric_name, evaluator, aliases = {})
          @registry ||= {}
          unless evaluator.included_modules.include?(Evaluators::BaseEvaluator)
            evaluator.include(Evaluators::BaseEvaluator)
          end

          @registry[metric_name.to_sym] = {
            evaluator: evaluator,
            aliases: (aliases || []).map(&:to_sym),
          }
        end

        def get(name)
          @registry ||= {}
          option = (@registry[name.to_sym] || @registry.detect do |_k, opts|
            opts[:aliases].include?(name.to_sym)
          end) || {}
          option.dig(:evaluator)
        end

        def metrics
          @registry.keys
        end

        def evaluate(model:, y_pred:, y_true:, x_true: nil, evaluator: nil)
          y_pred = normalize_input(y_pred)
          y_true = normalize_input(y_true)
          check_size(y_pred, y_true)

          metrics_results = {}

          model.metrics.each do |metric|
            evaluator_class = get(metric.to_sym)
            next unless evaluator_class

            evaluator_instance = evaluator_class.new
            metrics_results[metric.to_sym] = evaluator_instance.evaluate(
              y_pred: y_pred,
              y_true: y_true,
              x_true: x_true,
            )
          end

          if evaluator.present?
            evaluator = evaluator.symbolize_keys!
            evaluator_class = get(evaluator[:metric])
            raise "Unknown evaluator: #{evaluator}" unless evaluator_class

            evaluator_instance = evaluator_class.new
            response = evaluator_instance.evaluate(y_pred: y_pred, y_true: y_true, x_true: x_true)

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
          when Polars::DataFrame
            if input.columns.count > 1
              raise ArgumentError, "Don't know how to evaluate input with multiple columns: #{input}"
            end

            normalize_input(input[input.columns.first])
          when Polars::Series, Array
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
  %w[mae]
)
EasyML::Core::ModelEvaluator.register(
  :mean_squared_error,
  EasyML::Core::Evaluators::RegressionEvaluators::MeanSquaredError,
  %w[mse]
)
EasyML::Core::ModelEvaluator.register(
  :root_mean_squared_error,
  EasyML::Core::Evaluators::RegressionEvaluators::RootMeanSquaredError,
  %w[rmse]
)

EasyML::Core::ModelEvaluator.register(
  :r2_score,
  EasyML::Core::Evaluators::RegressionEvaluators::R2Score,
  %w[r2]
)
EasyML::Core::ModelEvaluator.register(
  :accuracy_score,
  EasyML::Core::Evaluators::ClassificationEvaluators::AccuracyScore,
  %w[accuracy]
)
EasyML::Core::ModelEvaluator.register(
  :precision_score,
  EasyML::Core::Evaluators::ClassificationEvaluators::PrecisionScore,
  %w[precision]
)
EasyML::Core::ModelEvaluator.register(
  :recall_score,
  EasyML::Core::Evaluators::ClassificationEvaluators::RecallScore,
  %w[recall]
)
EasyML::Core::ModelEvaluator.register(
  :f1_score,
  EasyML::Core::Evaluators::ClassificationEvaluators::F1Score,
  %w[f1]
)
