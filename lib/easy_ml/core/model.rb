require "carrierwave"

module EasyML
  module Core
    class Model
      include GlueGun::DSL

      attribute :name, :string
      attribute :version, :string
      attribute :verbose, :boolean, default: false
      attribute :task, :string, default: "regression"
      attribute :model_type, :string
      attribute :metrics, :array
      attribute :file, :string
      attribute :root_dir, :string
      attribute :objective
      attribute :evaluator
      attribute :evaluator_metric
      attribute :dataset

      def initialize(options = {})
        super
        apply_defaults
      end

      def fit(x_train: nil, y_train: nil, x_valid: nil, y_valid: nil)
        if x_train.nil?
          puts "Refreshing dataset"
          dataset.refresh
          puts "Train"
          train
        else
          train(x_train: x_train, y_train: y_train, x_valid: x_valid, y_valid: y_valid)
        end
        @is_fit = true
      end

      def predict(xs)
        raise NotImplementedError, "Subclasses must implement predict method"
      end

      def loaded?
        raise NotImplementedError, "Subclasses must implement loaded? method"
      end

      def load
        raise NotImplementedError, "Subclasses must implement load method"
      end

      def save_model_file
        raise NotImplementedError, "Subclasses must implement save_model_file method"
      end

      def decode_labels(ys, col: nil)
        dataset.decode_labels(ys, col: col)
      end

      def evaluate(y_pred: nil, y_true: nil, x_true: nil, evaluator: nil)
        evaluator ||= self.evaluator
        EasyML::Core::ModelEvaluator.evaluate(model: self, y_pred: y_pred, y_true: y_true, x_true: x_true,
                                              evaluator: evaluator)
      end

      def get_params
        @hyperparameters.to_h
      end

      def allowed_metrics
        return [] unless task.present?

        case task.to_sym
        when :regression
          %w[mean_absolute_error mean_squared_error root_mean_squared_error r2_score]
        when :classification
          %w[accuracy_score precision_score recall_score f1_score auc roc_auc]
        else
          []
        end
      end

      def fit?
        @is_fit == true
      end

      private

      def apply_defaults
        self.metrics ||= allowed_metrics
      end

      def dataset_is_a_dataset?
        return if dataset.nil?
        return if dataset.class.ancestors.include?(EasyML::Data::Dataset)

        errors.add(:dataset, "Must be a subclass of EasyML::Dataset")
      end

      def validate_any_metrics?
        return if metrics.any?

        errors.add(:metrics, "Must include at least one metric. Allowed metrics are #{allowed_metrics.join(", ")}")
      end

      def validate_metrics_for_task
        nonsensical_metrics = metrics.select do |metric|
          allowed_metrics.exclude?(metric)
        end

        return unless nonsensical_metrics.any?

        errors.add(:metrics,
                   "cannot use metrics: #{nonsensical_metrics.join(", ")} for task #{task}. Allowed metrics are: #{allowed_metrics.join(", ")}")
      end
    end
  end
end
