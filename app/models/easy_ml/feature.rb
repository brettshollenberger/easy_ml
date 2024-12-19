# == Schema Information
#
# Table name: easy_ml_features
#
#  id               :bigint           not null, primary key
#  dataset_id       :bigint           not null
#  name             :string
#  version          :bigint
#  feature_class    :string           not null
#  feature_position :integer
#  applied_at       :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
module EasyML
  class Feature < ActiveRecord::Base
    self.table_name = "easy_ml_features"
    include Historiographer::Silent
    historiographer_mode :snapshot_only

    # Associations
    belongs_to :dataset, class_name: "EasyML::Dataset"

    # Validations
    validates :feature_class, presence: true
    validates :feature_position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    before_validation :set_feature_position, on: :create

    # Scopes
    scope :ordered, -> { order(feature_position: :asc) }

    before_save :apply_defaults, if: :new_record?

    # Instance methods
    def feature_class_constant
      feature_class.constantize
    rescue NameError
      raise InvalidFeatureError, "Invalid feature class: #{feature_class}"
    end

    def apply!(df)
      feature_class_constant.new.transform(df, self)
    end

    # Position manipulation methods
    def insert
      save!
      self
    end

    def insert_where
      features = dataset.features.reload
      target_position = features.map(&:feature_position).max
      yield target_position
      features.select { |t| target_position.nil? || t.feature_position > target_position }.each { |t| t.feature_position += 1 }
      features += [self]

      bulk_update_positions(features)
      self
    end

    def prepend
      insert_where do |_position|
        self.feature_position = 0
      end
    end

    def insert_before
      insert_where do |position|
        self.feature_position = position - 1
      end
    end

    def insert_after
      insert_where do |position|
        self.feature_position = position + 1
      end
    end

    def bump_version
      write_attribute(:version, version + 1)
    end

    def apply_defaults
      self.name ||= self.feature_class.demodulize.titleize
      self.version ||= 1
    end

    private

    def bulk_update_positions(features)
      # Use activerecord-import for bulk updates
      features = order_features(features)
      features.each(&:apply_defaults)
      new_features = features.reject(&:persisted?)
      existing_features = features.select(&:persisted?)
      Feature.import(
        existing_features,
        on_duplicate_key_update: [:feature_position],
        validate: false,
      )
      Feature.import(new_features)
    end

    def order_features(features)
      features.sort_by { |t| t.feature_position }.each_with_index do |feature, index|
        feature.feature_position = index
      end
    end

    def set_feature_position
      return if feature_position.present?

      max_feature_position = dataset&.features&.maximum(:feature_position) || -1
      self.feature_position = max_feature_position + 1
    end
  end

  class InvalidFeatureError < StandardError; end
end
