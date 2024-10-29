require "numo/narray"
require_relative "evaluators/base_evaluator"
require_relative "evaluators/regression_evaluators"
require_relative "evaluators/classification_evaluators"
module EasyML
  module Core
    class ModelEvaluator
      class << self
        def register(metric_name, evaluator)
          @registry ||= {}
          unless evaluator.included_modules.include?(Evaluators::BaseEvaluator)
            evaluator.include(Evaluators::BaseEvaluator)
          end

          @registry[metric_name.to_sym] = evaluator
        end

        def get(name)
          @registry ||= {}
          @registry[name.to_sym]
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
              x_true: x_true
            )
          end

          if evaluator.present?
            evaluator_class = evaluator.is_a?(Class) ? evaluator : get(evaluator)
            raise "Unknown evaluator: #{evaluator}" unless evaluator_class

            evaluator_instance = evaluator_class.new
            response = evaluator_instance.evaluate(y_pred: y_pred, y_true: y_true, x_true: x_true)

            if response.is_a?(Hash)
              metrics_results.merge!(response)
            else
              metrics_results[evaluator_instance.metric] = response
            end
          end

          metrics_results
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
EasyML::Core::ModelEvaluator.register(:mean_absolute_error, EasyML::Core::Evaluators::MeanAbsoluteError)
EasyML::Core::ModelEvaluator.register(:mean_squared_error, EasyML::Core::Evaluators::MeanSquaredError)
EasyML::Core::ModelEvaluator.register(:root_mean_squared_error, EasyML::Core::Evaluators::RootMeanSquaredError)
EasyML::Core::ModelEvaluator.register(:r2_score, EasyML::Core::Evaluators::R2Score)
EasyML::Core::ModelEvaluator.register(:accuracy_score, EasyML::Core::Evaluators::AccuracyScore)
EasyML::Core::ModelEvaluator.register(:precision_score, EasyML::Core::Evaluators::PrecisionScore)
EasyML::Core::ModelEvaluator.register(:recall_score, EasyML::Core::Evaluators::RecallScore)
EasyML::Core::ModelEvaluator.register(:f1_score, EasyML::Core::Evaluators::F1Score)
