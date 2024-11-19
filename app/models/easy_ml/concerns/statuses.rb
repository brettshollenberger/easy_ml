require "active_support/concern"

module EasyML
  module Concerns
    module Statuses
      extend ActiveSupport::Concern

      STATUSES = %w[
        training
        inference
        retired
      ]
      included do
        scope :inference, -> { where(status: :inference) }
        scope :retired, -> { where(status: :retired) }
        scope :training, -> { where(status: :training) }

        validates :status, inclusion: { in: STATUSES }
        validates :status, presence: true
        validate :only_one_object_is_inference?

        before_update :ensure_no_conflicting_inference_status
        after_initialize :set_default_status, if: :new_record?
      end

      def set_default_status
        self.status ||= "training"
      end

      # Check if the current object is in inference status
      def inference?
        return false if status.nil?

        status.to_sym == :inference
      end

      # Check if the current object is retired
      def retired?
        return false if status.nil?

        status.to_sym == :retired
      end

      # Check if the current object is in training status
      def training?
        return false if status.nil?

        status.to_sym == :training
      end

      # Custom validation: Ensure only one object is in inference status for the same name
      def only_one_object_is_inference?
        return unless inference?

        return unless previous_versions.inference.any?

        errors.add(:status,
                   "cannot promote to inference mode when a previous version is already in inference. Use the `promote` method.")
      end

      # Ensure that only one inference is running when the status changes to inference
      def ensure_no_conflicting_inference_status
        return unless status_changed? && inference? && previous_versions.inference.exists?

        errors.add(:status,
                   "There is already an object running inference. Use `promote` to retire previous versions.")
      end

      # Promote the current object to inference status, retire previous versions
      def promote
        raise "Cannot promote without a name! Set name first." if name.nil?

        if respond_to?(:promotable?) && respond_to?(:cannot_promote_reasons) && !promotable?
          raise "Cannot promote: #{cannot_promote_reasons.join(", ")}"
        end

        transaction do
          # self.class.where(name: name).inference.where.not(id: id).update_all(status: :retired)
          update!(status: :inference)
        end
      end

      # Fetch previous retired versions of the current object, ordered by ID
      def previous_versions
        self.class.where(name: name).retired.order(id: :desc)
      end
    end
  end
end
