module EasyML
  module Core
    module Evaluators
      module BaseEvaluator
        def self.included(base)
          base.extend(ClassMethods)
        end

        # Instance methods that evaluators must implement
        def evaluate(y_pred: nil, y_true: nil, x_true: nil)
          raise NotImplementedError, "#{self.class} must implement #evaluate"
        end

        def calculate_result(metrics)
          metrics.symbolize_keys!
          metrics[metric.to_sym]
        end

        module ClassMethods
          def self.extended(base)
            class << base
              attr_accessor :registry
            end
          end
        end
      end
    end
  end
end
