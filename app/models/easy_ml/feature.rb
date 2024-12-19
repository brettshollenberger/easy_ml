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
#  sha              :string
#
module EasyML
  class Feature < ActiveRecord::Base
    self.table_name = "easy_ml_features"
    include Historiographer::Silent
    historiographer_mode :snapshot_only

    class << self
      def compute_sha(feature_class)
        require "digest"
        path = feature_class.constantize.instance_method(:transform).source_location.first
        current_mtime = File.mtime(path)
        cache_key = "feature_sha/#{path}"

        cached = Rails.cache.read(cache_key)

        if cached && cached[:mtime] == current_mtime
          cached[:sha]
        else
          # Compute new SHA and cache it with the current mtime
          sha = Digest::SHA256.hexdigest(File.read(path))
          Rails.cache.write(cache_key, { sha: sha, mtime: current_mtime })
          sha
        end
      end

      def clear_sha_cache!
        Rails.cache.delete_matched("feature_sha/*")
      end
    end

    # Associations
    belongs_to :dataset, class_name: "EasyML::Dataset"

    # Validations
    validates :feature_class, presence: true
    validates :feature_position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    before_validation :set_feature_position, on: :create

    # Scopes
    scope :ordered, -> { order(feature_position: :asc) }
    scope :has_changes, -> {
            # Get all unique feature classes
            feature_classes = pluck(:feature_class).uniq

            # Build conditions for each feature class
            conditions = feature_classes.map do |klass|
              current_sha = compute_sha(klass)
              sanitize_sql_array(["(feature_class = ? AND (sha IS NULL OR sha != ?))", klass, current_sha])
            end

            # Combine all conditions with OR
            where(conditions.join(" OR "))
          }
    scope :never_applied, -> { where(applied_at: nil) }
    scope :needs_recompute, -> { has_changes.or(never_applied) }

    before_save :apply_defaults, if: :new_record?
    before_save :update_sha

    # Instance methods
    def feature_class_constant
      feature_class.constantize
    rescue NameError
      raise InvalidFeatureError, "Invalid feature class: #{feature_class}"
    end

    def apply!(df)
      result = feature_class_constant.new.transform(df, self)
      update!(applied_at: Time.current)
      result
    end

    def code_changed?
      sha != compute_sha
    end

    def compute_sha
      self.class.compute_sha(feature_class)
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

    def update_sha
      self.sha = compute_sha
    end
  end

  class InvalidFeatureError < StandardError; end
end
