module EasyML
  class ModelEvaluator
    require "numo/narray"

    EVALUATORS = {
      mean_absolute_error: lambda { |y_pred, y_true|
        (Numo::DFloat.cast(y_pred) - Numo::DFloat.cast(y_true)).abs.mean
      },
      mean_squared_error: lambda { |y_pred, y_true|
        ((Numo::DFloat.cast(y_pred) - Numo::DFloat.cast(y_true))**2).mean
      },
      root_mean_squared_error: lambda { |y_pred, y_true|
        Math.sqrt(((Numo::DFloat.cast(y_pred) - Numo::DFloat.cast(y_true))**2).mean)
      },
      r2_score: lambda { |y_pred, y_true|
        # Convert inputs to Numo::DFloat for numerical operations
        y_true = Numo::DFloat.cast(y_true)
        y_pred = Numo::DFloat.cast(y_pred)

        # Calculate the mean of the true values
        mean_y = y_true.mean

        # Calculate Total Sum of Squares (SS_tot)
        ss_tot = ((y_true - mean_y)**2).sum

        # Calculate Residual Sum of Squares (SS_res)
        ss_res = ((y_true - y_pred)**2).sum

        # Handle the edge case where SS_tot is zero
        if ss_tot.zero?
          if ss_res.zero?
            # Perfect prediction when both SS_tot and SS_res are zero
            1.0
          else
            # Undefined R² when SS_tot is zero but SS_res is not
            Float::NAN
          end
        else
          # Calculate R²
          1 - (ss_res / ss_tot)
        end
      },
      accuracy_score: lambda { |y_pred, y_true|
        y_pred = Numo::Int32.cast(y_pred)
        y_true = Numo::Int32.cast(y_true)
        y_pred.eq(y_true).count_true.to_f / y_pred.size
      },
      precision_score: lambda { |y_pred, y_true|
        y_pred = Numo::Int32.cast(y_pred)
        y_true = Numo::Int32.cast(y_true)
        true_positives = (y_pred.eq(1) & y_true.eq(1)).count_true
        predicted_positives = y_pred.eq(1).count_true
        return 0 if predicted_positives == 0

        true_positives.to_f / predicted_positives
      },
      recall_score: lambda { |y_pred, y_true|
        y_pred = Numo::Int32.cast(y_pred)
        y_true = Numo::Int32.cast(y_true)
        true_positives = (y_pred.eq(1) & y_true.eq(1)).count_true
        actual_positives = y_true.eq(1).count_true
        true_positives.to_f / actual_positives
      },
      f1_score: lambda { |y_pred, y_true|
        precision = EVALUATORS[:precision_score].call(y_pred, y_true) || 0
        recall = EVALUATORS[:recall_score].call(y_pred, y_true) || 0
        return 0 unless (precision + recall) > 0

        2 * (precision * recall) / (precision + recall)
      }
    }

    class << self
      def evaluate(model: nil, y_pred: nil, y_true: nil)
        y_pred = normalize_input(y_pred)
        y_true = normalize_input(y_true)
        check_size(y_pred, y_true)

        metrics_results = {}

        model.metrics.each do |metric|
          if metric.is_a?(Module) || metric.is_a?(Class)
            unless metric.respond_to?(:evaluate)
              raise "Metric #{metric} must respond to #evaluate in order to be used as a custom evaluator"
            end

            metrics_results[metric.name] = metric.evaluate(y_pred, y_true)
          elsif EVALUATORS.key?(metric.to_sym)
            metrics_results[metric.to_sym] =
              EVALUATORS[metric.to_sym].call(y_pred, y_true)
          end
        end

        metrics_results
      end

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
