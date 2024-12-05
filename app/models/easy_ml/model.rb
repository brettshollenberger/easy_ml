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
    self.table_name = "easy_ml_models"
    include Historiographer::Silent
    historiographer_mode :snapshot_only

    include EasyML::Concerns::Configurable
    include EasyML::Concerns::Versionable

    self.filter_attributes += [:configuration]

    MODEL_OPTIONS = {
      "xgboost" => "EasyML::Models::XGBoost"
    }
    MODEL_TYPES = [
      {
        value: "xgboost",
        label: "XGBoost",
        description: "Extreme Gradient Boosting, a scalable and accurate implementation of gradient boosting machines"
      }
    ].freeze
    MODEL_NAMES = MODEL_OPTIONS.keys.freeze
    MODEL_CONSTANTS = MODEL_OPTIONS.values.map(&:constantize)

    add_configuration_attributes :task, :objective, :hyperparameters, :evaluator, :callbacks, :metrics
    MODEL_CONSTANTS.flat_map(&:configuration_attributes).each do |attribute|
      add_configuration_attributes attribute
    end

    belongs_to :dataset
    has_one :model_file, class_name: "EasyML::ModelFile"

    has_many :retraining_runs, class_name: "EasyML::RetrainingRun"

    after_initialize :bump_version, if: -> { new_record? }
    after_initialize :set_defaults, if: -> { new_record? }
    before_save :save_model_file, if: -> { is_fit? && !is_history_class? }

    VALID_TASKS = %i[regression classification].freeze

    validates :task, presence: true
    validates :task, inclusion: {
      in: VALID_TASKS.map { |t| [t, t.to_s] }.flatten,
      message: "must be one of: #{VALID_TASKS.join(", ")}"
    }
    validates :model_type, inclusion: { in: MODEL_NAMES }
    validates :dataset_id, presence: true
    before_save :set_root_dir

    delegate :prepare_data, :callbacks, :preprocess, to: :model_adapter

    STATUSES = %w[training inference retired]
    STATUSES.each do |status|
      define_method "#{status}?" do
        self.status.to_sym == status.to_sym
      end
    end

    def inference_version
      snap = latest_snapshot # returns EasyML::Model.none (empty array) if none, return nil instead
      snap.present? ? snap : nil
    end

    def hyperparameters
      @hypers ||= model_adapter.build_hyperparameters(@hyperparameters)
    end

    def predict(xs)
      load_model!
      model_adapter.predict(xs)
    end

    def save_model_file
      raise "No trained model! Need to train model before saving (call model.fit)" unless is_fit?

      model_file = get_model_file

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
      get_model_file&.cleanup!
    end

    def cleanup
      get_model_file&.cleanup(files_to_keep)
    end

    def loaded?
      model_file = get_model_file
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
      return true if model_file.present? && !model_file.persisted?
      return true if model_file.present? && model_file.fit? && inference_version.nil?

      prev_hash = Digest::SHA256.file(inference_version.model_file.full_path).hexdigest
      model_adapter.model_changed?(prev_hash)
    end

    def fork
      dup.tap do |new_model|
        new_model.status = :training
        new_model.version = bump_version(force: true)
        new_model.model_file = nil
        new_model.save
      end
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

    attr_accessor :is_fit

    def is_fit?
      model_file = get_model_file
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
        hyperparameters: hyperparameters.to_h
      )
    end

    class CannotPromoteError < StandardError
    end

    def promote
      raise CannotPromoteError, cannot_promote_reasons.first if cannot_promote_reasons.any?

      save
      dataset.lock
      snapshot
      bump_version(force: true)
      dataset.bump_versions(version)
      save
    end

    def inference_pipeline(df); end

    def cannot_promote_reasons
      [
        is_fit? ? nil : "Model has not been trained",
        dataset.target.present? ? nil : "Dataset has no target",
        !dataset.datasource.in_memory? ? nil : "Cannot perform inference using an in-memory datasource",
        model_changed? ? nil : "Model has not changed"
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

    private

    def underscored_name
      name.gsub(/\s{2,}/, " ").gsub(/\s/, "_").downcase
    end

    def get_model_file
      model_file || build_model_file(
        root_dir: root_dir,
        model: self,
        s3_bucket: EasyML::Configuration.s3_bucket,
        s3_region: EasyML::Configuration.s3_region,
        s3_access_key_id: EasyML::Configuration.s3_access_key_id,
        s3_secret_access_key: EasyML::Configuration.s3_secret_access_key,
        s3_prefix: prefix
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

    def load_model(force: false)
      download_model_file(force: force)
      load_model_file
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
      return unless force
      return if loaded?

      get_model_file.download
    end

    def files_to_keep
      inference_models = EasyML::ModelHistory.latest_snapshots
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
      self.metrics ||= allowed_metrics
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
