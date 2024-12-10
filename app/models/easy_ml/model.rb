# == Schema Information
#
# Table name: easy_ml_models
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  model_type      :string
#  status          :string
#  dataset_id      :bigint
#  model_file_id   :bigint
#  configuration   :json
#  version         :string           not null
#  root_dir        :string
#  file            :json
#  sha             :string
#  last_trained_at :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
require_relative "models/hyperparameters"

module EasyML
  class Model < ActiveRecord::Base
    self.table_name = "easy_ml_models"
    include Historiographer::Silent
    historiographer_mode :snapshot_only

    include EasyML::Concerns::Configurable
    include EasyML::Concerns::Versionable

    self.filter_attributes += [:configuration]

    MODEL_OPTIONS = {
      "xgboost" => "EasyML::Models::XGBoost",
    }
    MODEL_TYPES = [
      {
        value: "xgboost",
        label: "XGBoost",
        description: "Extreme Gradient Boosting, a scalable and accurate implementation of gradient boosting machines",
      },
    ].freeze
    MODEL_NAMES = MODEL_OPTIONS.keys.freeze
    MODEL_CONSTANTS = MODEL_OPTIONS.values.map(&:constantize)

    add_configuration_attributes :task, :objective, :hyperparameters, :evaluator, :callbacks, :metrics
    MODEL_CONSTANTS.flat_map(&:configuration_attributes).each do |attribute|
      add_configuration_attributes attribute
    end

    belongs_to :dataset
    has_many :model_files, class_name: "EasyML::ModelFile"
    has_one :deployed_model_file, -> { where(deployed: true) }, class_name: "EasyML::ModelFile"

    has_one :retraining_job, class_name: "EasyML::RetrainingJob"
    accepts_nested_attributes_for :retraining_job
    has_many :retraining_runs, class_name: "EasyML::RetrainingRun"

    after_initialize :bump_version, if: -> { new_record? }
    after_initialize :set_defaults, if: -> { new_record? }
    before_save :save_model_file, if: -> { is_fit? && !is_history_class? && model_changed? && !@skip_save_model_file }

    VALID_TASKS = %i[regression classification].freeze

    TASK_TYPES = [
      {
        value: "classification",
        label: "Classification",
        description: "Predict categorical outcomes or class labels",
      },
      {
        value: "regression",
        label: "Regression",
        description: "Predict continuous numerical values",
      },
    ].freeze

    validates :name, presence: true
    validates :name, uniqueness: { case_sensitive: false }
    validates :task, presence: true
    validates :task, inclusion: {
                       in: VALID_TASKS.map { |t| [t, t.to_s] }.flatten,
                       message: "must be one of: #{VALID_TASKS.join(", ")}",
                     }
    validates :model_type, inclusion: { in: MODEL_NAMES }
    validates :dataset_id, presence: true
    validate :validate_metrics_allowed
    before_save :set_root_dir

    delegate :prepare_data, :preprocess, to: :model_adapter

    STATUSES = %w[development inference retired]
    STATUSES.each do |status|
      define_method "#{status}?" do
        self.status.to_sym == status.to_sym
      end
    end

    def latest_model_file
      @model_file ||= model_files.order(id: :desc).limit(1)&.first
    end

    def train(async: true)
      evaluator = self.evaluator.symbolize_keys
      job = retraining_job || create_retraining_job(active: false, evaluator: evaluator, metric: evaluator.dig(:metric), direction: evaluator.dig(:direction), threshold: evaluator.dig(:threshold), frequency: "day", at: { hour: 0 })
      run = job.retraining_runs.create!(status: "pending", model_id: self.id)
      if async
        EasyML::RetrainingWorker.perform_async(run.id)
      else
        EasyML::RetrainingWorker.new.perform(run.id)
      end
      run
    end

    def training?
      retraining_runs.running.any?
    end

    def deployment_status
      status
    end

    def formatted_model_type
      model_adapter.class.name.split("::").last
    end

    def formatted_version
      return nil unless version
      Time.strptime(version, "%Y%m%d%H%M%S").strftime("%B %-d, %Y at %-l:%M %p")
    end

    def last_run_at
      last_run&.created_at
    end

    def last_run
      retraining_runs.order(id: :desc).limit(1).last
    end

    def inference_version
      snap = latest_snapshot # returns EasyML::Model.none (empty array) if none, return nil instead
      snap.present? ? snap : nil
    end

    def hyperparameters
      @hypers ||= model_adapter.build_hyperparameters(@hyperparameters)
    end

    def callbacks
      @cbs ||= model_adapter.build_callbacks(@callbacks)
    end

    def predict(xs)
      load_model!
      model_adapter.predict(xs)
    end

    def save_model_file
      raise "No trained model! Need to train model before saving (call model.fit)" unless is_fit?

      model_file = new_model_file!

      bump_version(force: true)
      path = model_file.full_path(version)
      full_path = model_adapter.save_model_file(path)
      model_file.upload(full_path)

      model_file.save
      cleanup
    end

    def feature_names
      model_adapter.feature_names
    end

    def cleanup!
      latest_model_file&.cleanup!
    end

    def cleanup
      latest_model_file&.cleanup(files_to_keep)
    end

    def loaded?
      model_file = deployed_model_file
      return false if model_file.persisted? && !File.exist?(model_file.full_path.to_s)

      file_exists = true
      if model_file.present? && model_file.persisted? && model_file.full_path.present?
        file_exists = File.exist?(model_file.full_path)
      end

      loaded = model_adapter.loaded?
      load_model_file unless loaded
      file_exists && model_adapter.loaded?
    end

    def model_changed?
      return false unless is_fit?
      return true if latest_model_file.nil?
      return true if latest_model_file.present? && !latest_model_file.persisted?
      return true if latest_model_file.present? && latest_model_file.fit? && inference_version.nil?

      model_adapter.model_changed?(inference_version.sha)
    end

    def feature_importances
      model_adapter.feature_importances
    end

    def fit(x_train: nil, y_train: nil, x_valid: nil, y_valid: nil)
      if x_train.nil?
        puts "Refreshing dataset"
        dataset.refresh
      end
      model_adapter.fit(x_train: x_train, y_train: y_train, x_valid: x_valid, y_valid: y_valid)
      @is_fit = true
    end

    def fit_in_batches(batch_size: 1024, overlap: 0.1, checkpoint_dir: Rails.root.join("tmp", "xgboost_checkpoints"))
      model_adapter.fit_in_batches(batch_size: batch_size, overlap: overlap, checkpoint_dir: checkpoint_dir)
      @is_fit = true
    end

    attr_accessor :is_fit

    def is_fit?
      model_file = latest_model_file
      return true if model_file.present? && model_file.fit?

      model_adapter.is_fit?
    end

    def promotable?
      cannot_promote_reasons.none?
    end

    def decode_labels(ys, col: nil)
      dataset.decode_labels(ys, col: col)
    end

    def evaluate(y_pred: nil, y_true: nil, x_true: nil, evaluator: nil)
      evaluator ||= self.evaluator
      if y_pred.nil?
        inputs = default_evaluation_inputs
        y_pred = inputs[:y_pred]
        y_true = inputs[:y_true]
        x_true = inputs[:x_true]
      end
      EasyML::Core::ModelEvaluator.evaluate(model: self, y_pred: y_pred, y_true: y_true, x_true: x_true, evaluator: evaluator)
    end

    def evaluator
      read_attribute(:evaluator) || default_evaluator
    end

    def default_evaluator
      return nil unless task.present?

      EasyML::Core::ModelEvaluator.default_evaluator(task)
    end

    def get_params
      @hyperparameters.to_h
    end

    def evals
      last_run&.metrics || {}
    end

    def metric_accessor(metric)
      metrics = last_run.metrics.symbolize_keys
      metrics.dig(metric.to_sym)
    end

    EasyML::Core::ModelEvaluator.metrics.each do |metric_name|
      define_method metric_name do
        metric_accessor(metric_name)
      end
    end

    EasyML::Core::ModelEvaluator.callbacks = lambda do |metric_name|
      EasyML::Model.define_method metric_name do
        metric_accessor(metric_name)
      end
    end

    def allowed_metrics
      EasyML::Core::ModelEvaluator.metrics(task).map(&:to_s)
    end

    def default_metrics
      return [] unless task.present?

      case task.to_sym
      when :regression
        %w[mean_absolute_error mean_squared_error root_mean_squared_error r2_score]
      when :classification
        %w[accuracy_score precision_score recall_score f1_score]
      else
        []
      end
    end

    def self.constants
      {
        objectives: objectives_by_model_type,
        metrics: metrics_by_task,
        tasks: TASK_TYPES,
        timezone: EasyML::Configuration.timezone_label,
        retraining_job_constants: EasyML::RetrainingJob.constants,
        tuner_job_constants: EasyML::TunerJob.constants,
      }
    end

    def self.metrics_by_task
      EasyML::Core::ModelEvaluator.metrics_by_task
    end

    def self.objectives_by_model_type
      MODEL_OPTIONS.inject({}) do |h, (k, v)|
        h.tap do
          h[k] = v.constantize.const_get(:OBJECTIVES_FRONTEND)
        end
      end.deep_symbolize_keys
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

      # Prepare the inference model by freezing + saving the model, dataset, and datasource
      # (This creates ModelHistory, DatasetHistory, etc)
      save_model_file
      self.sha = latest_model_file.sha

      EasyML::Model.transaction do
        deployed_model_file
        latest_model_file.deployed_at = Time.now
        latest_model_file.deployed = true
        save
        dataset.lock
        snapshot
      end

      # Prepare the model to be retrained (reset values so they don't conflict with our snapshotted version)
      bump_version(force: true)
      dataset.bump_versions(version)
      save
      true
    end

    def inference_pipeline(df); end

    def cannot_promote_reasons
      [
        is_fit? ? nil : "Model has not been trained",
        dataset.target.present? ? nil : "Dataset has no target",
        !dataset.datasource.in_memory? ? nil : "Cannot perform inference using an in-memory datasource",
        model_changed? ? nil : "Model has not changed",
      ].compact
    end

    def root_dir=(value)
      raise "Cannot override value of root_dir!" unless value.to_s == root_dir.to_s

      write_attribute(:root_dir, value)
    end

    def set_root_dir
      write_attribute(:root_dir, root_dir)
    end

    def root_dir
      EasyML::Engine.root_dir.join("models").join(underscored_name).to_s
    end

    def load_model(force: false)
      download_model_file(force: force)
      load_model_file
    end

    def metrics=(value)
      value = [value] unless value.is_a?(Array)
      value = value.map(&:to_s)
      value = value.uniq
      @metrics = value
    end

    private

    def default_evaluation_inputs
      x_true, y_true = dataset.test(split_ys: true)
      y_pred = predict(x_true)
      {
        x_true: x_true,
        y_true: y_true,
        y_pred: y_pred,
      }
    end

    def underscored_name
      name.gsub(/\s{2,}/, " ").gsub(/\s/, "_").downcase
    end

    def new_model_file!
      model_files.new(
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
      load_dataset
    end

    def load_dataset
      dataset.load_dataset
    end

    def load_model_file
      return unless model_file&.full_path && File.exist?(model_file.full_path)

      begin
        model_adapter.load_model_file(model_file.full_path)
      rescue StandardError => e
        binding.pry
      end
    end

    def download_model_file(force: false)
      return unless persisted?
      return if loaded? && !force

      get_model_file.download
    end

    def files_to_keep
      inference_files = EasyML::ModelHistory.latest_snapshots.includes(:model_files).map(&:deployed_model_file)
      training_files = EasyML::Model.all.includes(:model_files).map(&:latest_model_file)

      (inference_files + training_files).compact.map(&:full_path).uniq
    end

    def underscored_name
      name = self.name || self.class.name.split("::").last
      name.gsub(/\s{2,}/, " ").gsub(/\s/, "_").downcase
    end

    def set_defaults
      self.model_type ||= "xgboost"
      self.status ||= :training
      self.metrics ||= default_metrics
    end

    def validate_metrics_allowed
      unknown_metrics = metrics.select { |metric| allowed_metrics.exclude?(metric) }
      return unless unknown_metrics.any?

      errors.add(:metrics,
                 "don't know how to handle #{"metrics".pluralize(unknown_metrics)} #{unknown_metrics.join(", ")}, use EasyML::Core::ModelEvaluator.register(:name, Evaluator, :regression|:classification)")
    end

    def model_adapter
      @model_adapter ||= begin
          adapter_class = MODEL_OPTIONS[model_type]
          raise "Don't know how to use model adapter #{model_type}!" unless adapter_class.present?

          adapter_class.constantize.new(self)
        end
    end
  end
end

require_relative "models/xgboost"
