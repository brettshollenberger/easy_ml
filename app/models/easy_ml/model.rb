# == Schema Information
#
# Table name: easy_ml_models
#
#  id            :bigint           not null, primary key
#  name          :string           not null
#  model_type    :string
#  status        :string
#  dataset_id    :bigint
#  model_file_id :bigint
#  configuration :json
#  version       :string           not null
#  root_dir      :string
#  file          :json
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
require_relative "concerns/statuses"

module EasyML
  class Model < ActiveRecord::Base
    include EasyML::Concerns::Statuses
    include EasyML::FileSupport

    self.filter_attributes += [:configuration]

    self.table_name = "easy_ml_models"

    include GlueGun::Model
    service :xgboost, EasyML::Core::Models::XGBoost

    belongs_to :dataset
    has_one :model_file,
            class_name: "EasyML::ModelFile"

    after_find :load_model
    after_initialize :generate_version_string
    around_save :save_model_file, if: -> { fit? }

    # before_save :save_statistics
    # before_save :save_hyperparameters

    # validates :task, inclusion: { in: %i[regression classification] }
    # validates :task, presence: true
    # validate :dataset_is_a_dataset?
    # validate :validate_any_metrics?
    # validate :validate_metrics_for_task

    # def save_statistics
    #   write_attribute(:statistics, dataset.statistics.deep_symbolize_keys)
    # end

    # def save_hyperparameters
    #   binding.pry
    #   write_attribute(:hyperparameters, hyperparameters.to_h)
    # end

    def save_model_file
      raise "No trained model! Need to train model before saving (call model.fit)" unless fit?

      self.model_file = get_model_file
      full_path = model_file.full_path(version)
      full_path = model_service.save_model_file(full_path)
      model_file.upload(full_path)

      yield

      model_file.save
      cleanup
    end

    def cleanup!
      get_model_file&.cleanup!
    end

    def cleanup
      get_model_file&.cleanup
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
        s3_prefix: prefix
      )
    end

    def prefix
      s3_prefix = EasyML::Configuration.s3_prefix
      s3_prefix.present? ? File.join(s3_prefix, name) : name
    end

    def load_model
      return unless persisted?

      get_model_file.download
      model_service.load(get_model_file.full_path.to_s)
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

    def generate_version_string
      return version if version.present?

      timestamp = Time.now.utc.strftime("%Y%m%d%H%M%S")
      self.version = "#{model_type}_#{timestamp}"
    end
  end
end
