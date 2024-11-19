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
    validates :transform_position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    before_validation :set_transform_position, on: :create

    # Scopes
    scope :ordered, -> { order(transform_position: :asc) }

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
      target_position = target&.transform_position
      yield target_position
      transforms.select { |t| target_position.nil? || t.transform_position > target_position }.each { |t| t.transform_position += 1 }
      transforms += [self]

      bulk_update_positions(transforms)
      self
    end

    def prepend
      insert_where(nil) do |_position|
        self.transform_position = 0
      end
    end

    def insert_before(transform_method)
      insert_where(transform_method) do |position|
        self.transform_position = position - 1
      end
    end

    def insert_after(transform_method)
      insert_where(transform_method) do |position|
        self.transform_position = position + 1
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
        on_duplicate_key_update: [:transform_position],
        validate: false,
      )
      Transform.import(new_transforms)
    end

    def order_transforms(transforms)
      transforms.sort_by { |t| t.transform_position }.each_with_index do |transform, index|
        transform.transform_position = index
      end
    end

    def set_transform_position
      return if transform_position.present?

      max_transform_position = dataset&.transforms&.maximum(:transform_position) || -1
      self.transform_position = max_transform_position + 1
    end
  end

  class InvalidTransformError < StandardError; end
end
