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
#  is_training     :boolean
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
    belongs_to :model_file, class_name: "EasyML::ModelFile", foreign_key: "model_file_id", optional: true

    has_one :retraining_job, class_name: "EasyML::RetrainingJob"
    accepts_nested_attributes_for :retraining_job
    has_many :retraining_runs, class_name: "EasyML::RetrainingRun"
    has_many :deploys, class_name: "EasyML::Deploy"

    scope :deployed, -> { EasyML::ModelHistory.deployed }

    def latest_deploy
      deploys.order(id: :desc).limit(1).last
    end

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

    delegate :prepare_data, :preprocess, to: :adapter

    STATUSES = %w[development inference retired]
    STATUSES.each do |status|
      define_method "#{status}?" do
        self.status.to_sym == status.to_sym
      end
    end

    def training?
      is_training == true
    end

    def train(async: true)
      pending_run # Ensure we update the pending job before enqueuing in background so UI updates properly
      update(is_training: true)
      if async
        EasyML::TrainingJob.perform_later(id)
      else
        actually_train
      end
    end

    def get_retraining_job
      if retraining_job
        self.evaluator = retraining_job.evaluator
        evaluator = self.evaluator.symbolize_keys
      else
        default_eval = Core::ModelEvaluator.default_evaluator(task)
        self.evaluator = default_eval
        evaluator = default_eval
      end

      retraining_job || create_retraining_job(
        model: self,
        active: false,
        evaluator: evaluator,
        metric: evaluator[:metric],
        direction: evaluator[:direction],
        threshold: evaluator[:threshold],
        frequency: "month",
        at: { hour: 0, day_of_month: 1 },
      )
    end

    def pending_run
      job = get_retraining_job
      job.retraining_runs.find_or_create_by(status: "pending", model: self)
    end

    def actually_train(&progress_block)
      lock_model do
        run = pending_run
        run.wrap_training do
          best_params = nil
          if run.should_tune?
            best_params = hyperparameter_search(&progress_block)
          end
          fit(&progress_block)
          save
          [self, best_params]
        end
        update(is_training: false)
        run.reload
      ensure
        unlock!
      end
    end

    def unlock!
      Support::Lockable.unlock!(lock_key)
    end

    def lock_model
      with_lock do |client|
        yield
      end
    end

    def with_lock
      EasyML::Support::Lockable.with_lock(lock_key, stale_timeout: 60, resources: 1) do |client|
        yield client
      end
    end

    def lock_key
      "training:#{self.name}:#{self.id}"
    end

    def hyperparameter_search(&progress_block)
      tuner = retraining_job.tuner_config.symbolize_keys
      extra_params = {
        evaluator: evaluator,
        model: self,
        dataset: dataset,
      }.compact
      tuner.merge!(extra_params)
      tuner_instance = EasyML::Core::Tuner.new(tuner)
      tuner_instance.tune(&progress_block).tap do |best_params|
        best_params.each do |key, value|
          self.hyperparameters.send("#{key}=", value)
        end
      end
    end

    def deployment_status
      status
    end

    def formatted_model_type
      adapter.class.name.split("::").last
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
      latest_deploy&.model_version
    end

    alias_method :current_version, :inference_version
    alias_method :latest_version, :inference_version
    alias_method :deployed, :inference_version

    def hyperparameters
      @hypers ||= adapter.build_hyperparameters(@hyperparameters)
    end

    def callbacks
      @cbs ||= adapter.build_callbacks(@callbacks)
    end

    def predict(xs)
      load_model!
      adapter.predict(xs)
    end

    def save_model_file
      raise "No trained model! Need to train model before saving (call model.fit)" unless is_fit?
      return unless adapter.loaded?

      model_file = get_model_file

      bump_version(force: true)
      path = model_file.full_path(version)
      full_path = adapter.save_model_file(path)
      puts "saving model to #{full_path}"
      model_file.upload(full_path)

      model_file.save
      self.model_file = model_file
      cleanup
    end

    def feature_names
      adapter.feature_names
    end

    def cleanup!
      get_model_file&.cleanup!
    end

    def cleanup
      puts "keeping files #{files_to_keep}"
      get_model_file&.cleanup(files_to_keep)
    end

    def loaded?
      model_file = get_model_file
      return false if model_file.persisted? && !File.exist?(model_file.full_path.to_s)

      file_exists = true
      if model_file.present? && model_file.persisted? && model_file.full_path.present?
        file_exists = File.exist?(model_file.full_path)
      end

      loaded = adapter.loaded?
      load_model_file unless loaded
      file_exists && adapter.loaded?
    end

    def model_changed?
      return false unless is_fit?
      return true if inference_version.nil?
      return true if model_file.present? && !model_file.persisted?
      return true if model_file.present? && model_file.fit? && inference_version.nil?

      adapter.model_changed?(inference_version.sha)
    end

    def feature_importances
      adapter.feature_importances
    end

    def fit_in_batches?
      retraining_job.present? && retraining_job.batch_mode == true
    end

    def fit(tuning: false, x_train: nil, y_train: nil, x_valid: nil, y_valid: nil, &progress_block)
      return fit_in_batches(**batch_args.merge!(tuning: tuning), &progress_block) if fit_in_batches?

      dataset.refresh
      adapter.fit(tuning: tuning, x_train: x_train, y_train: y_train, x_valid: x_valid, y_valid: y_valid, &progress_block)
      @is_fit = true
    end

    def batch_args
      defaults = {
        batch_size: 1024,
        batch_overlap: 3,
        batch_key: nil,
      }
      overrides = { batch_size: retraining_job&.batch_size, batch_overlap: retraining_job&.batch_overlap, batch_key: retraining_job&.batch_key }.compact
      defaults.merge!(overrides)
    end

    def batch_mode
      retraining_job&.batch_mode || false
    end

    def prepare_callbacks(tune_started_at)
      adapter.prepare_callbacks(tune_started_at)
    end

    def after_tuning
      adapter.after_tuning
    end

    def fit_in_batches(tuning: false, batch_size: nil, batch_overlap: nil, batch_key: nil, checkpoint_dir: Rails.root.join("tmp", "xgboost_checkpoints"), &progress_block)
      adapter.fit_in_batches(tuning: tuning, batch_size: batch_size, batch_overlap: batch_overlap, batch_key: batch_key, checkpoint_dir: checkpoint_dir, &progress_block)
      @is_fit = true
    end

    attr_accessor :is_fit

    def is_fit?
      model_file = get_model_file
      return true if model_file.present? && model_file.fit?

      adapter.is_fit?
    end

    def deployable?
      cannot_deploy_reasons.none?
    end

    def decode_labels(ys, col: nil)
      dataset.decode_labels(ys, col: col)
    end

    def evaluate(y_pred: nil, y_true: nil, x_true: nil, evaluator: nil, dataset: nil)
      evaluator ||= self.evaluator
      if y_pred.nil?
        inputs = default_evaluation_inputs
        y_pred = inputs[:y_pred]
        y_true = inputs[:y_true]
        x_true = inputs[:x_true]
        dataset = inputs[:dataset]
      end
      EasyML::Core::ModelEvaluator.evaluate(model: self, y_pred: y_pred, y_true: y_true, x_true: x_true, dataset: dataset, evaluator: evaluator)
    end

    def evaluator
      instance_variable_get(:@evaluator) || default_evaluator
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

    def api_fields
      dataset.columns.where(is_computed: false).map(&:to_api)
    end

    class CannotdeployError < StandardError
    end

    def deploy(async: true)
      last_run.deploy(async: async)
    end

    def actually_deploy
      raise CannotdeployError, cannot_deploy_reasons.first if cannot_deploy_reasons.any?

      # Prepare the inference model by freezing + saving the model, dataset, and datasource
      # (This creates ModelHistory, DatasetHistory, etc)
      save_model_file
      self.sha = model_file.sha
      save
      dataset.upload_remote_files
      snapshot.tap do
        # Prepare the model to be retrained (reset values so they don't conflict with our snapshotted version)
        bump_version(force: true)
        dataset.bump_versions(version)
        self.model_file = new_model_file!
        save
      end
    end

    def cannot_deploy_reasons
      [
        is_fit? ? nil : "Model has not been trained",
        dataset.target.present? ? nil : "Dataset has no target",
        !dataset.datasource.in_memory? ? nil : "Cannot perform inference using an in-memory datasource",
      ].compact
    end

    def root_dir=(value)
      raise "Cannot override value of root_dir!" unless value.to_s == root_dir.to_s

      write_attribute(:root_dir, value)
    end

    def set_root_dir
      write_attribute(:root_dir, default_root_dir)
    end

    def root_dir
      relative_dir = read_attribute(:root_dir) || default_root_dir

      EasyML::Engine.root_dir.join(relative_dir).to_s
    end

    def default_root_dir
      File.join("models", underscored_name).to_s
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

    def adapter
      @adapter ||= begin
          adapter_class = MODEL_OPTIONS[model_type]
          raise "Don't know how to use model adapter #{model_type}!" unless adapter_class.present?

          adapter_class.constantize.new(self)
        end
    end

    private

    def default_evaluation_inputs
      x_true, y_true = dataset.test(split_ys: true)
      ds = dataset.test(all_columns: true)
      y_pred = predict(x_true)
      {
        x_true: x_true,
        y_true: y_true,
        y_pred: y_pred,
        dataset: ds,
      }
    end

    def underscored_name
      name.gsub(/\s{2,}/, " ").gsub(/\s/, "_").downcase
    end

    def get_model_file
      model_file || new_model_file!
    end

    def new_model_file!
      build_model_file(
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

      adapter.load_model_file(model_file.full_path)
    end

    def download_model_file(force: false)
      return unless persisted?
      return if loaded? && !force

      get_model_file.download
    end

    def files_to_keep
      inference_models = EasyML::ModelHistory.deployed
      training_models = EasyML::Model.all

      ([self] + training_models + inference_models).compact.map(&:model_file).compact.map(&:full_path).uniq
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
  end
end

require_relative "models/xgboost"
