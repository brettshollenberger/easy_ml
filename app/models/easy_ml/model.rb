require_relative "../../../lib/easy_ml/core/model_service"
# t.string :ml_model
# t.string :task
# t.string :metrics, array: true
# t.json :file, null: false
# t.json :statistics
# t.json :hyperparameters
module EasyML
  class Model < ActiveRecord::Base
    self.table_name = "easy_ml_models"

    extend CarrierWave::Mount
    mount_uploader :file, EasyML::Core::Uploaders::ModelUploader

    scope :live, -> { where(is_live: true) }
    attribute :root_dir, :string
    validate :only_one_model_is_live?

    def initialize(options = {})
      options.deep_symbolize_keys!
      db_options = options.slice(*(options.keys & self.class.column_names.map(&:to_sym)))
      super(db_options)
      build_model_service(options)
    end

    def self.models
      {
        xgboost: EasyML::Core::Models::XGBoostService
      }
    end

    attr_accessor :model_service

    def build_model_service(options)
      unless options.key?(:model) && EasyML::Model.models[options[:model]].present?
        raise "Must specify one of allowed models: #{models.join(", ")}"
      end

      service_klass = EasyML::Model.models[options[:model]]

      @model_service ||= service_klass.new(options)
    end

    delegate :cleanup!, to: :model_service
    # before_save :save_statistics
    # before_save :save_hyperparameters

    # validates :task, inclusion: { in: %i[regression classification] }
    # validates :task, presence: true
    # validate :dataset_is_a_dataset?
    # validate :validate_any_metrics?
    # validate :validate_metrics_for_task
    # before_validation :save_model_file, if: -> { fit? }

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
                 "cannot mark model live when previous version is live. Explicitly use the mark_live method to mark this as the live version")
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

    after_find :load_model

    private

    def load_model
      load if persisted?
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
