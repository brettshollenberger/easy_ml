require "carrierwave"
require_relative "uploaders/model_uploader"

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

      def root_dir
        @root_dir ||= detect_root_dir
      end

      def fit(x_train: nil, y_train: nil, x_valid: nil, y_valid: nil)
        if x_train.nil?
          dataset.refresh
          train
        else
          train(x_train: x_train, y_train: y_train, x_valid: x_valid, y_valid: y_valid)
        end
        @is_fit = true
      end

      def predict(xs)
        raise NotImplementedError, "Subclasses must implement predict method"
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

      def cleanup!
        [carrierwave_dir, model_dir].each do |dir|
          EasyML::FileRotate.new(dir, []).cleanup(extension_allowlist)
        end
      end

      def cleanup
        [carrierwave_dir, model_dir].each do |dir|
          EasyML::FileRotate.new(dir, files_to_keep).cleanup(extension_allowlist)
        end
      end

      def fit?
        @is_fit == true
      end

      private

      def carrierwave_dir
        return unless file.present?

        dir = File.dirname(file).split("/")[0..-2].join("/")
        return unless dir.start_with?(Rails.root.to_s)

        dir
      end

      def extension_allowlist
        EasyML::Core::Uploaders::ModelUploader.new.extension_allowlist
      end

      def ensure_directory_exists(dir)
        FileUtils.mkdir_p(dir) unless File.directory?(dir)
      end

      def apply_defaults
        self.metrics ||= allowed_metrics
      end

      def model_dir
        File.join(root_dir, "easy_ml_models", name.present? ? name.split.join.underscore : "")
      end

      def files_to_keep
        Dir.glob(File.join(carrierwave_dir, "**/*")).select { |f| File.file?(f) }.sort_by do |filename|
          Time.parse(filename.split("/").last.gsub(/\D/, ""))
        end.reverse.take(5)
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
