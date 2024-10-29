module EasyML
  module Core
    module Evaluators
      class AccuracyScore
        include BaseEvaluator

        def evaluate(y_pred:, y_true:, x_true: nil)
          y_pred = Numo::Int32.cast(y_pred)
          y_true = Numo::Int32.cast(y_true)
          y_pred.eq(y_true).count_true.to_f / y_pred.size
        end
      end

      class PrecisionScore
        include BaseEvaluator

        def evaluate(y_pred:, y_true:, x_true: nil)
          y_pred = Numo::Int32.cast(y_pred)
          y_true = Numo::Int32.cast(y_true)
          true_positives = (y_pred.eq(1) & y_true.eq(1)).count_true
          predicted_positives = y_pred.eq(1).count_true
          return 0 if predicted_positives.zero?

          true_positives.to_f / predicted_positives
        end
      end

      class RecallScore
        include BaseEvaluator

        def evaluate(y_pred:, y_true:, x_true: nil)
          y_pred = Numo::Int32.cast(y_pred)
          y_true = Numo::Int32.cast(y_true)
          true_positives = (y_pred.eq(1) & y_true.eq(1)).count_true
          actual_positives = y_true.eq(1).count_true
          true_positives.to_f / actual_positives
        end
      end

      class F1Score
        include BaseEvaluator

        def evaluate(y_pred:, y_true:, x_true: nil)
          precision = PrecisionScore.new.evaluate(y_pred: y_pred, y_true: y_true)
          recall = RecallScore.new.evaluate(y_pred: y_pred, y_true: y_true)
          return 0 unless (precision + recall) > 0

          2 * (precision * recall) / (precision + recall)
        end
      end
    end
  end
end
