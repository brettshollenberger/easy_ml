require_relative "../../../lib/easy_ml/core/model"
module EasyML
  class Model < ActiveRecord::Base
    include EasyML::Core::Model
    self.table_name = "easy_ml_models"

    scope :live, -> { where(is_live: true) }

    validate :only_one_model_is_live?
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
      # Start a transaction to ensure atomicity
      transaction do
        self.class.where(name: name).where.not(id: id).update_all(is_live: false)
        self.class.where(id: id).update_all(is_live: true)
      end
    end

    def previous_versions
      EasyML::Model.where(name: name).order(id: :desc)
    end

    private

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
