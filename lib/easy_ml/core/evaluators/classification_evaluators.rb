module EasyML
  module Core
    module Evaluators
      module ClassificationEvaluators
        class AccuracyScore
          include BaseEvaluator

          def evaluate(y_pred:, y_true:, x_true: nil, dataset: nil)
            y_pred = Numo::Int32.cast(y_pred)
            y_true = Numo::Int32.cast(y_true)
            y_pred.eq(y_true).count_true.to_f / y_pred.size
          end

          def description
            "Overall prediction accuracy"
          end

          def direction
            "maximize"
          end
        end

        class PrecisionScore
          include BaseEvaluator

          def evaluate(y_pred:, y_true:, x_true: nil, dataset: nil)
            y_pred = Numo::Int32.cast(y_pred)
            y_true = Numo::Int32.cast(y_true)
            true_positives = (y_pred.eq(1) & y_true.eq(1)).count_true
            predicted_positives = y_pred.eq(1).count_true
            return 0 if predicted_positives.zero?

            true_positives.to_f / predicted_positives
          end

          def description
            "Ratio of true positives to predicted positives"
          end

          def direction
            "maximize"
          end
        end

        class RecallScore
          include BaseEvaluator

          def evaluate(y_pred:, y_true:, x_true: nil, dataset: nil)
            y_pred = Numo::Int32.cast(y_pred)
            y_true = Numo::Int32.cast(y_true)
            true_positives = (y_pred.eq(1) & y_true.eq(1)).count_true
            actual_positives = y_true.eq(1).count_true
            true_positives.to_f / actual_positives
          end

          def description
            "Ratio of true positives to actual positives"
          end

          def direction
            "maximize"
          end
        end

        class F1Score
          include BaseEvaluator

          def evaluate(y_pred:, y_true:, x_true: nil, dataset: nil)
            precision = PrecisionScore.new.evaluate(y_pred: y_pred, y_true: y_true, dataset: dataset)
            recall = RecallScore.new.evaluate(y_pred: y_pred, y_true: y_true, dataset: dataset)
            return 0 unless (precision + recall) > 0

            2 * (precision * recall) / (precision + recall)
          end

          def description
            "Harmonic mean of precision and recall"
          end

          def direction
            "maximize"
          end
        end

        class AUC
          include BaseEvaluator

          def evaluate(y_pred:, y_true:, x_true: nil, dataset: nil)
            y_pred = Numo::DFloat.cast(y_pred)
            y_true = Numo::Int32.cast(y_true)

            sorted_indices = y_pred.sort_index
            y_pred[sorted_indices]
            y_true_sorted = y_true[sorted_indices]

            true_positive_rate = []
            false_positive_rate = []

            positive_count = y_true_sorted.eq(1).count_true
            negative_count = y_true_sorted.eq(0).count_true

            tp = 0
            fp = 0

            y_true_sorted.each do |label|
              if label == 1
                tp += 1
              else
                fp += 1
              end
              true_positive_rate << tp.to_f / positive_count
              false_positive_rate << fp.to_f / negative_count
            end

            # Compute the AUC using the trapezoidal rule
            tpr = Numo::DFloat[*true_positive_rate]
            fpr = Numo::DFloat[*false_positive_rate]

            auc = ((fpr[1..-1] - fpr[0...-1]) * (tpr[1..-1] + tpr[0...-1]) / 2.0).sum
            auc
          end

          def description
            "Area under the ROC curve"
          end

          def direction
            "maximize"
          end
        end

        class ROC_AUC
          include BaseEvaluator

          def evaluate(y_pred:, y_true:, x_true: nil, dataset: nil)
            AUC.new.evaluate(y_pred: y_pred, y_true: y_true, dataset: dataset)
          end

          def description
            "Area under the ROC curve"
          end

          def direction
            "maximize"
          end
        end
      end
    end
  end
end
