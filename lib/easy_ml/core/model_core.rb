require "carrierwave"
require_relative "uploaders/model_uploader"

module EasyML
  module Core
    module ModelCore
      attr_accessor :dataset

      def self.included(base)
        base.send(:include, GlueGun::DSL)
        base.send(:extend, CarrierWave::Mount)
        base.send(:mount_uploader, :file, EasyML::Core::Uploaders::ModelUploader)

        base.class_eval do
          validates :task, inclusion: { in: %w[regression classification] }
          validates :task, presence: true
          validate :dataset_is_a_dataset?
          validate :validate_any_metrics?
          validate :validate_metrics_for_task
          before_validation :save_model_file, if: -> { fit? }
        end
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

      def fit(x_train: nil, y_train: nil, x_valid: nil, y_valid: nil)
        if x_train.nil?
          dataset.refresh!
          train_in_batches
        else
          train(x_train, y_train, x_valid, y_valid)
        end
        @is_fit = true
      end

      def decode_labels(ys, col: nil)
        dataset.decode_labels(ys, col: col)
      end

      def evaluate(y_pred: nil, y_true: nil)
        EasyML::Core::ModelEvaluator.evaluate(model: self, y_pred: y_pred, y_true: y_true)
      end

      def predict(xs)
        raise NotImplementedError, "Subclasses must implement predict method"
      end

      def load
        raise NotImplementedError, "Subclasses must implement load method"
      end

      def _save_model_file
        raise NotImplementedError, "Subclasses must implement _save_model_file method"
      end

      def save
        super if defined?(super) && self.class.superclass.method_defined?(:save)
        save_model_file
      end

      def save_model_file
        raise "No trained model! Need to train model before saving (call model.fit)" unless fit?

        path = File.join(model_dir, "#{version}.json")
        ensure_directory_exists(File.dirname(path))

        _save_model_file(path)

        File.open(path) do |f|
          self.file = f
        end
        file.store!

        cleanup
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
        [file_dir, model_dir].each do |dir|
          EasyML::FileRotate.new(dir, []).cleanup(extension_allowlist)
        end
      end

      def cleanup
        [file_dir, model_dir].each do |dir|
          EasyML::FileRotate.new(dir, files_to_keep).cleanup(extension_allowlist)
        end
      end

      def fit?
        @is_fit == true
      end

      private

      def file_dir
        return unless file.path.present?

        File.dirname(file.path).split("/")[0..-2].join("/")
      end

      def extension_allowlist
        EasyML::Core::Uploaders::ModelUploader.new.extension_allowlist
      end

      def _save_model_file(path = nil)
        raise NotImplementedError, "Subclasses must implement _save_model_file method"
      end

      def ensure_directory_exists(dir)
        FileUtils.mkdir_p(dir) unless File.directory?(dir)
      end

      def apply_defaults
        self.version ||= generate_version_string
        self.ml_model ||= get_ml_model
      end

      def get_ml_model
        self.class.name.split("::").last.underscore
      end

      def generate_version_string
        timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
        model_name = self.class.name.split("::").last.underscore
        "#{model_name}_#{timestamp}"
      end

      def model_dir
        File.join(root_dir, "easy_ml_models", name.present? ? name.split.join.underscore : "")
      end

      def files_to_keep
        Dir.glob(File.join(file_dir, "*")).select { |f| File.file?(f) }.sort_by do |filename|
          Time.parse(filename.split("/").last.gsub(/\D/, ""))
        end.reverse.take(5)
      end
    end
  end
end
