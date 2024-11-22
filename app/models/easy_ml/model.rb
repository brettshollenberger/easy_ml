# == Schema Information
#
# Table name: easy_ml_models
#
#  id            :bigint           not null, primary key
#  name          :string           not null
#  model_type    :string
#  status        :string
#  dataset_id    :bigint
#  configuration :json
#  version       :string           not null
#  root_dir      :string
#  file          :json
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
require_relative "models/hyperparameters"

module EasyML
  class Model < ActiveRecord::Base
    self.inheritance_column = :model_type
    self.table_name = "easy_ml_models"
    include Historiographer::Silent
    historiographer_mode :snapshot_only

    include EasyML::Concerns::Configurable
    include EasyML::Support::FileSupport

    self.filter_attributes += [:configuration]

    MODEL_TYPES = [
      {
        value: "xgboost",
        label: "XGBoost",
        description: "Extreme Gradient Boosting, a scalable and accurate implementation of gradient boosting machines",
      },
    ].freeze

    self.inheritance_column = :model_type

    add_configuration_attributes :task, :objective, :hyperparameters, :evaluator, :callbacks
    attr_accessor :task, :metrics, :hyperparameters, :objective, :evaluator, :callbacks

    belongs_to :dataset
    has_one :model_file, class_name: "EasyML::ModelFile"

    has_many :retraining_runs, class_name: "EasyML::RetrainingRun"

    after_initialize :generate_version_string
    after_initialize :set_defaults
    before_save :save_model_file, if: -> { is_fit? && !is_history_class? }

    VALID_TASKS = %i[regression classification].freeze

    validates :task, presence: true
    validates :task, inclusion: {
                       in: VALID_TASKS.map { |t| [t, t.to_s] }.flatten,
                       message: "must be one of: #{VALID_TASKS.join(", ")}",
                     }

    def predict(_xs)
      raise "#predict not implemented! Must be implemented by subclasses"
    end

    def around_predict
      load_model!
      yield
    end

    def around_save_model_file
      raise "No trained model! Need to train model before saving (call model.fit)" unless is_fit?

      model_file = get_model_file

      generate_version_string(force: true)
      path = model_file.full_path(version)
      full_path = yield(path)
      model_file.upload(full_path)

      model_file.save
      cleanup
    end

    def cleanup!
      get_model_file&.cleanup!
    end

    def cleanup
      get_model_file&.cleanup(files_to_keep)
    end

    def around_loaded
      model_file = get_model_file
      return false if model_file.persisted? && !File.exist?(model_file.full_path.to_s)

      loaded = yield
      load_model_file unless loaded
      yield
    end

    def model_changed?
      raise "#model_changed? not implemented! Must be implemented by subclasses"
    end

    def fork
      dup.tap do |new_model|
        new_model.status = :training
        new_model.version = generate_version_string(force: true)
        new_model.model_file = nil
        new_model.save
      end
    end

    def fit(x_train: nil, y_train: nil, x_valid: nil, y_valid: nil)
      raise "#fit not implemented! Must be implemented by subclasses"
    end

    def around_fit(x_train)
      if x_train.nil?
        puts "Refreshing dataset"
        dataset.refresh
      end
      yield
      @is_fit = true
    end

    attr_accessor :is_fit

    def around_is_fit?
      model_file = get_model_file
      return true if model_file.present? && model_file.fit?

      yield
    end

    def cannot_promote_reasons
      [
        is_fit? ? nil : "Model has not been trained",
      ].compact
    end

    def promotable?
      cannot_promote_reasons.none?
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

    def attributes
      super.merge!(
        hyperparameters: hyperparameters.to_h,
      )
    end

    class CannotPromoteError < StandardError
    end

    def promote
      raise CannotPromoteError, cannot_promote_reasons.first if cannot_promote_reasons.any?

      dataset.lock
      snapshot
    end

    def inference_pipeline(df)
    end

    def cannot_promote_reasons
      [
        is_fit? ? nil : "Model has not been trained",
        dataset.target.present? ? nil : "Dataset has no target",
        !dataset.datasource.in_memory? ? nil : "Cannot perform inference using an in-memory datasource",
      ]
    end

    private

    def get_model_file
      model_file || build_model_file(
        root_dir: root_dir,
        model: self,
        s3_bucket: EasyML::Configuration.s3_bucket,
        s3_region: EasyML::Configuration.s3_region,
        s3_access_key_id: EasyML::Configuration.s3_access_key_id,
        s3_secret_access_key: EasyML::Configuration.s3_secret_access_key,
        s3_prefix: prefix,
      )
    end

    def prefix
      s3_prefix = EasyML::Configuration.s3_prefix
      s3_prefix.present? ? File.join(s3_prefix, name) : name
    end

    def load_model!
      load_model(force: true)
    end

    def load_model(force: false)
      download_model_file(force: force)
      load_model_file
    end

    def loading_model_file
      return unless model_file&.full_path && File.exist?(model_file.full_path)

      yield(model_file.full_path)
    end

    def download_model_file(force: false)
      return unless persisted?
      return unless force
      return if loaded?

      get_model_file.download
    end

    def files_to_keep
      inference_models = EasyML::ModelHistory.latest_snapshots
      training_models = EasyML::Model.all

      ([self] + training_models + inference_models).compact.map(&:model_file).compact.map(&:full_path).uniq
    end

    def generate_version_string(force: false)
      return version if version.present? && !force

      timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
      self.version = "#{underscored_name}_#{timestamp}"
    end

    def underscored_name
      name = self.name || self.class.name.split("::").last
      name.gsub(/\s{2,}/, " ").gsub(/\s/, "_").downcase
    end

    def set_defaults
      self.model_type ||= "EasyML::Models::XGBoost"
      self.status ||= :training
      self.metrics ||= allowed_metrics
    end
  end
end

require_relative "models/xgboost"
