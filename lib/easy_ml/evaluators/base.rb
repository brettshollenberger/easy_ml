module EasyML
  module Evaluators
    class Base
      include EasyML::Core::Evaluators::BaseEvaluator

      def evaluate(y_pred:, y_true:, x_true: nil)
        raise NotImplementedError, "#{self.class} must implement #evaluate"
      end

      # Default to minimizing, subclasses can override
      def direction
        :minimize
      end

      # Allow evaluators to specify if they support a specific task type
      def self.supports_task?(task)
        true
      end

      # Optional description for the UI
      def self.description
        ""
      end
    end
  end
end
