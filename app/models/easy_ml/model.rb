require "carrierwave"
require "carrierwave/orm/activerecord"
require_relative "../../uploaders/model_uploader"

module EasyML
  class Model < ActiveRecord::Base
    self.table_name = "easy_ml_models"
    mount_uploader :file, EasyML::ModelUploader

    include GlueGun::DSL

    validates :name, presence: true
    validate :only_one_model_is_live?

    scope :live, -> { where(is_live: true) }

    def only_one_model_is_live?
      if previous_versions.live.count > 1
        raise "Multiple previous versions of #{name} are live! This should never happen. Update previous versions to is_live=false before proceeding"
      end

      return unless previous_versions.live.any? && live

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

    def fit(xs, ys)
      raise NotImplementedError, "Subclasses must implement fit method"
    end

    def predict(xs)
      raise NotImplementedError, "Subclasses must implement predict method"
    end

    def save_model_file(path = nil)
      raise NotImplementedError, "Subclasses must implement save_model_file method"
    end

    def fit?
      raise NotImplementedError, "Subclasses must implement fit? method"
    end

    def load
      raise NotImplementedError, "Subclasses must implement load method"
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

    private

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

    def generate_file_path
      Rails.root.join("tmp", "models", "#{version}.bin").to_s
    end
  end
end
