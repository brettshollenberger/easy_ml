module EasyML
  module Core
    module Evaluators
      module RegressionEvaluators
        class MeanAbsoluteError
          include BaseEvaluator

          def evaluate(y_pred:, y_true:, x_true: nil)
            (Numo::DFloat.cast(y_pred) - Numo::DFloat.cast(y_true)).abs.mean
          end
        end

        class MeanSquaredError
          include BaseEvaluator

          def evaluate(y_pred:, y_true:, x_true: nil)
            ((Numo::DFloat.cast(y_pred) - Numo::DFloat.cast(y_true)) ** 2).mean
          end
        end

        class RootMeanSquaredError
          include BaseEvaluator

          def evaluate(y_pred:, y_true:, x_true: nil)
            Math.sqrt(((Numo::DFloat.cast(y_pred) - Numo::DFloat.cast(y_true)) ** 2).mean)
          end
        end

        class R2Score
          include BaseEvaluator

          def evaluate(y_pred:, y_true:, x_true: nil)
            y_true = Numo::DFloat.cast(y_true)
            y_pred = Numo::DFloat.cast(y_pred)

            mean_y = y_true.mean
            ss_tot = ((y_true - mean_y) ** 2).sum
            ss_res = ((y_true - y_pred) ** 2).sum

            if ss_tot.zero?
              ss_res.zero? ? 1.0 : Float::NAN
            else
              1 - (ss_res / ss_tot)
            end
          end
        end
      end
    end
  end
end
