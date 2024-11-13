# == Schema Information
#
# Table name: easy_ml_transforms
#
#  id               :bigint           not null, primary key
#  dataset_id       :bigint           not null
#  name             :string
#  transform_class  :string           not null
#  transform_method :string           not null
#  position         :integer
#  applied_at       :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
module EasyML
  class Transform < ActiveRecord::Base
    self.table_name = "easy_ml_transforms"

    # Associations
    belongs_to :dataset, class_name: "EasyML::Dataset"

    # Validations
    validates :transform_class, presence: true
    validates :transform_method, presence: true
    validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    before_validation :set_position, on: :create
    after_save :touch_dataset

    # Scopes
    scope :ordered, -> { order(position: :asc) }

    # Instance methods
    def transform_class_constant
      transform_class.constantize
    rescue NameError
      raise InvalidTransformError, "Invalid transform class: #{transform_class}"
    end

    def apply!(df)
      transform_class_constant.new.public_send(transform_method, df)
    end

    # Position manipulation methods
    def insert
      save!
      self
    end

    def insert_where(transform_method)
      transforms = dataset.transforms.reload
      target = transforms.detect { |t| t.transform_method.to_sym == transform_method }
      target_position = target&.position
      yield target_position
      transforms.select { |t| target_position.nil? || t.position > target_position }.each { |t| t.position += 1 }
      transforms += [self]

      bulk_update_positions(transforms)
      self
    end

    def prepend
      insert_where(nil) do |_position|
        self.position = 0
      end
    end

    def insert_before(transform_method)
      insert_where(transform_method) do |position|
        self.position = position - 1
      end
    end

    def insert_after(transform_method)
      insert_where(transform_method) do |position|
        self.position = position + 1
      end
    end

    private

    def bulk_update_positions(transforms)
      # Use activerecord-import for bulk updates
      transforms = order_transforms(transforms)
      new_transforms = transforms.reject(&:persisted?)
      existing_transforms = transforms.select(&:persisted?)
      Transform.import(
        existing_transforms,
        on_duplicate_key_update: [:position],
        validate: false
      )
      Transform.import(new_transforms)
    end

    def order_transforms(transforms)
      transforms.sort_by { |t| t.position }.each_with_index do |transform, index|
        transform.position = index
      end
    end

    def set_position
      return if position.present?

      max_position = dataset&.transforms&.maximum(:position) || -1
      self.position = max_position + 1
    end

    def touch_dataset
      dataset.touch
    end
  end

  class InvalidTransformError < StandardError; end
end
