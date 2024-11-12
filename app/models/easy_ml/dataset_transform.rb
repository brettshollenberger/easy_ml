module EasyML
  class DatasetTransform < ActiveRecord::Base
    self.table_name = "easy_ml_dataset_transforms"

    # Associations
    belongs_to :dataset, class_name: "EasyML::Dataset"

    # Validations
    validates :transform_class, presence: true
    validates :transform_method, presence: true
    validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    before_validation :set_position, on: :create

    # Scopes
    scope :ordered, -> { order(position: :asc) }

    # Instance methods
    def transform_class_constant
      transform_class.constantize
    rescue NameError
      raise InvalidTransformError, "Invalid transform class: #{transform_class}"
    end

    def apply!
      return if applied?

      transform_class_constant.public_send(transform_method, dataset, parameters || {})

      update!(
        applied_at: Time.current
      )
    rescue StandardError => e
      update!(
        parameters: parameters.merge(error: e.message)
      )
      raise
    end

    private

    def set_position
      return if position.present?

      max_position = dataset&.dataset_transforms&.maximum(:position) || -1
      self.position = max_position + 1
    end
  end

  class InvalidTransformError < StandardError; end
end
