module EasyML
  module Evaluators
    class << self
      def register_all
        Dir.glob(Rails.root.join("app/evaluators/**/*.rb")).each { |f| require f }

        ObjectSpace.each_object(Class).select { |klass|
          klass < EasyML::Evaluators::Base
        }.each do |evaluator_class|
          register_evaluator(evaluator_class)
        end
      end

      private

      def register_evaluator(evaluator_class)
        # Convert class name to snake_case for the evaluator name
        # e.g., WeightedMAE becomes weighted_mae
        name = evaluator_class.name.demodulize.titleize.gsub(/Evaluator/, "").strip

        EasyML::Core::ModelEvaluator.register(
          name,
          evaluator_class,
          get_supported_tasks(evaluator_class),
          [],
        )
      end

      def get_supported_tasks(evaluator_class)
        if evaluator_class.respond_to?(:supports_task?)
          [:regression, :classification].select { |task| evaluator_class.supports_task?(task) }
        else
          [:regression, :classification] # Default to supporting both if not specified
        end
      end
    end
  end
end

# Register all evaluators when the initializer loads
EasyML::Evaluators.register_all
