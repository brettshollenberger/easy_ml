module EasyML
  class Model < ActiveRecord::Base
    self.filter_attributes += [:configuration]

    self.table_name = "easy_ml_models"

    include GlueGun::Model
    service :xgboost, EasyML::Core::Models::XGBoost

    extend CarrierWave::Mount
    mount_uploader :file, EasyML::Core::Uploaders::ModelUploader

    scope :live, -> { where(is_live: true) }
    attribute :root_dir, :string
    validate :only_one_model_is_live?

    # before_save :save_statistics
    # before_save :save_hyperparameters

    # validates :task, inclusion: { in: %i[regression classification] }
    # validates :task, presence: true
    # validate :dataset_is_a_dataset?
    # validate :validate_any_metrics?
    # validate :validate_metrics_for_task
    after_initialize :generate_version_string
    before_validation :save_model_file, if: -> { fit? }

    # def save_statistics
    #   write_attribute(:statistics, dataset.statistics.deep_symbolize_keys)
    # end

    # def save_hyperparameters
    #   binding.pry
    #   write_attribute(:hyperparameters, hyperparameters.to_h)
    # end

    def only_one_model_is_live?
      return if @marking_live

      if previous_versions.live.count > 1
        raise "Multiple previous versions of #{name} are live! This should never happen. Update previous versions to is_live=false before proceeding"
      end

      return unless previous_versions.live.any? && is_live

      errors.add(:is_live,
                 "cannot mark mode      path ||= file.pathl live when previous version is live. Explicitly use the mark_live method to mark this as the live version")
    end

    def mark_live
      transaction do
        self.class.where(name: name).where.not(id: id).update_all(is_live: false)
        self.class.where(id: id).update_all(is_live: true)
      end
    end

    def previous_versions
      EasyML::Model.where(name: name).order(id: :desc)
    end

    def save_model_file
      raise "No trained model! Need to train model before saving (call model.fit)" unless fit?

      path = model_service.save_model_file(version)

      File.open(path) do |f|
        self.file = f
      end
      file.store!

      cleanup
    end

    after_find :load_model

    private

    def load_model
      return unless persisted?

      binding.pry
      file.retrieve_from_store!(file.identifier) unless File.exist?(file.path)
      model_service.load(file.path)
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
