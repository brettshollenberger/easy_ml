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
require_relative "concerns/statuses"
require_relative "models/hyperparameters"
module EasyML
  class Model < ActiveRecord::Base
    include EasyML::Concerns::Statuses
    include EasyML::Concerns::ConfigurableSTI
    include EasyML::FileSupport

    self.filter_attributes += [:configuration]

    self.table_name = "easy_ml_models"

    MODEL_TYPES = [
      {
        value: "xgboost",
        label: "XGBoost",
        description: "Extreme Gradient Boosting, a scalable and accurate implementation of gradient boosting machines"
      }
    ].freeze
    type_column :model_type
    register_module "EasyML::Models"
    register_types(
      xgboost: "XGBoost"
    )
    attr_accessor :task, :metrics, :objective, :hyperparameters, :evaluator, :callbacks

    add_configuration_attributes :task, :objective, :hyperparameters, :evaluator, :callbacks

    belongs_to :dataset
    has_one :model_file,
            class_name: "EasyML::ModelFile"

    has_many :retraining_runs, class_name: "EasyML::RetrainingRun"

    after_initialize :check_model_status
    after_initialize :generate_version_string
    after_initialize :set_defaults
    before_save :save_model_file, if: -> { fit? }

    VALID_TASKS = %i[regression classification].freeze

    validates :task, presence: true
    validates :task, inclusion: {
      in: VALID_TASKS.map { |t| [t, t.to_s] }.flatten,
      message: "must be one of: #{VALID_TASKS.join(", ")}"
    }

    def predict(_xs)
      raise "#predict not implemented! Must be implemented by subclasses"
    end

    def around_predict
      load_model!
      yield
    end

    def around_save_model_file
      raise "No trained model! Need to train model before saving (call model.fit)" unless fit?

      model_file = get_model_file

      # Only save new model file updates if the file is in training,
      # NO UPDATES to production inference models!
      if training?
        path = model_file.full_path(version)
        # full_path = model_service.save_model_file(full_path)
        full_path = yield(path)
        model_file.upload(full_path)
      end

      model_file.save if training?
      cleanup
    end

    def cleanup!
      get_model_file&.cleanup!
    end

    def cleanup
      get_model_file&.cleanup(files_to_keep)
    end

    def around_loaded
      return false unless File.exist?(get_model_file.full_path.to_s)

      loaded = yield
      load_model_file unless loaded
      yield
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
      raise "Cannot train #{status} model!" unless training?

      if x_train.nil?
        puts "Refreshing dataset"
        dataset.refresh
      end
      yield
      @is_fit = true
    end
    attr_accessor :is_fit

    def fit?
      return true if model_file.present? && model_file.fit?

      is_fit
    end

    def cannot_promote_reasons
      [
        fit? ? nil : "Model has not been trained"
      ].compact
    end

    def promotable?
      cannot_promote_reasons.none?
    end

    private

    def get_model_file
      model_file || build_model_file(
        root_dir: root_dir,
        model: self,
        model_file_type: EasyML::Configuration.storage&.to_sym || "s3",
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
    end

    def load_model(force: false)
      download_model_file(force: force)
      load_model_file
    end

    def loading_model_file
      return unless File.exist?(model_file.full_path)

      yield(model_file.full_path)
    end

    def download_model_file(force: false)
      return unless persisted?
      return unless force || inference?
      return if loaded?

      get_model_file.download
    end

    def files_to_keep
      live_models = self.class.inference

      recent_copies = live_models.flat_map do |live|
        # Fetch all models with the same name
        self.class.where(name: live.name).where.not(status: :inference).order(created_at: :desc).limit(live.name == name ? 4 : 5)
      end

      recent_versions = self.class
                            .where.not(
                              "EXISTS (SELECT 1 FROM easy_ml_models e2
                                WHERE e2.name = easy_ml_models.name AND e2.status = 'inference')"
                            )
                            .where("created_at >= ?", 2.days.ago)
                            .order(created_at: :desc)
                            .group_by(&:name)
                            .flat_map { |_, models| models.take(5) }
      ([self] + recent_versions + recent_copies + live_models).compact.map(&:model_file).compact.map(&:full_path).uniq
    end

    def generate_version_string(force: false)
      return version if version.present? && !force

      timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
      self.version = "#{model_type}_#{timestamp}"
    end

    def check_model_status
      return unless new_record? && !training?

      raise "Models must begin as status=training! You may not initialize a model as inference —— explicitly use model.promote to promote the model to production."
    end

    def set_defaults
      self.model_type ||= "EasyML::Models::XGBoost"
      self.status ||= :training
    end
  end
end
