require "carrierwave"
require "carrierwave/orm/activerecord"
require_relative "../../uploaders/model_uploader"

module EasyML
  class Model < ActiveRecord::Base
    self.table_name = "easy_ml_models"
    mount_uploader :file, EasyML::ModelUploader

    include GlueGun::DSL

    attribute :objective, :string
    validates :objective,
              inclusion: { in: %w[binary:logistic binary:hinge multi:softmax multi:softprob reg:squarederror
                                  reg:logistic] }

    validates :name, presence: true
    validate :only_one_model_is_live?

    scope :live, -> { where(is_live: true) }

    def only_one_model_is_live?
      return if @marking_live

      if previous_versions.live.count > 1
        raise "Multiple previous versions of #{name} are live! This should never happen. Update previous versions to is_live=false before proceeding"
      end

      return unless previous_versions.live.any? && is_live

      errors.add(:is_live,
                 "cannot mark model live when previous version is live. Explicitly use the mark_live method to mark this as the live version")
    end

    after_initialize :apply_defaults
    before_validation :save_model_file, if: -> { fit? }

    attr_accessor :dataset

    validate :dataset_is_a_dataset?

    def dataset_is_a_dataset?
      return if dataset.nil?
      return if dataset.class.ancestors.include?(EasyML::Data::Dataset)

      errors.add(:dataset, "Must be a subclass of EasyML::Dataset")
    end

    validates :task, inclusion: { in: %w[regression classification] }

    attribute :root_dir, :string

    def initialize(options = {})
      super(options.reverse_merge!(task: "regression"))
    end

    validate :validate_any_metrics
    def validate_any_metrics
      return if metrics.any?

      errors.add(:metrics, "Must include at least one metric. Allowed metrics are #{allowed_metrics.join(", ")}")
    end

    validate :validate_metrics_for_task
    def validate_metrics_for_task
      nonsensical_metrics = metrics.select do |metric|
        allowed_metrics.exclude?(metric)
      end

      return unless nonsensical_metrics.any?

      errors.add(:metrics,
                 "cannot use metrics: #{nonsensical_metrics.join(", ")} for task #{task}. Allowed metrics are: #{allowed_metrics.join(", ")}")
    end

    def mark_live
      # Start a transaction to ensure atomicity
      transaction do
        self.class.where(name: name).where.not(id: id).update_all(is_live: false)
        self.class.where(id: id).update_all(is_live: true)
      end
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
      EasyML::ModelEvaluator.evaluate(model: self, y_pred: y_pred, y_true: y_true)
    end

    def predict(xs)
      raise NotImplementedError, "Subclasses must implement predict method"
    end

    def load
      raise NotImplementedError, "Subclasses must implement load method"
    end

    def save_model_file
      raise "No trained model! Need to train model before saving (call model.fit)" unless fit?

      path ||= file.path if file.respond_to?(:path)
      path ||= model_dir.join("#{version}.json").to_s

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
      case task.to_sym
      when :regression
        %w[mean_absolute_error mean_squared_error root_mean_squared_error r2_score]
      when :classification
        %w[accuracy_score precision_score recall_score f1_score auc roc_auc]
      else
        []
      end
    end

    def previous_versions
      EasyML::Model.where(name: name).order(id: :desc)
    end

    def cleanup!
      EasyML::FileRotate.new(model_dir, []).cleanup(EasyML::ModelUploader.new.extension_allowlist)
    end

    def cleanup
      EasyML::FileRotate.new(model_dir, files_to_keep).cleanup(EasyML::ModelUploader.new.extension_allowlist)
    end

    def fit?
      @is_fit == true
    end

    private

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
      Rails.root.join("tmp/easy_ml_models")
    end

    def files_to_keep
      live_models = self.class.live

      recent_copies = live_models.flat_map do |live|
        # Fetch all models with the same name
        self.class.where(name: live.name).where(is_live: false).order(created_at: :desc).limit(live.name == name ? 4 : 5)
      end

      recent_versions = self.class
                            .where.not(
                              "EXISTS (SELECT 1 FROM easy_ml_models e2 WHERE e2.name = easy_ml_models.name AND e2.is_live = true)"
                            )
                            .where("created_at >= ?", 2.days.ago)
                            .order(created_at: :desc)
                            .group_by(&:name)
                            .flat_map { |_, models| models.take(5) }

      ([self] + recent_versions + recent_copies + live_models).compact.map(&:file).map(&:path).uniq
    end
  end
end
