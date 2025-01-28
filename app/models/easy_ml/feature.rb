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
#  batch_size       :integer
#  needs_fit        :boolean
#  sha              :string
#  primary_key      :string           is an Array
#  applied_at       :datetime
#  fit_at           :datetime
#  refresh_every    :bigint
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  workflow_status  :string
#
module EasyML
  class Feature < ActiveRecord::Base
    self.table_name = "easy_ml_features"
    include Historiographer::Silent
    historiographer_mode :snapshot_only

    enum workflow_status: {
      analyzing: "analyzing",
      ready: "ready",
      failed: "failed",
    }
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

    belongs_to :dataset, class_name: "EasyML::Dataset"

    validates :feature_class, presence: true
    validates :feature_position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    before_validation :set_feature_position, on: :create

    scope :ordered, -> { order(feature_position: :asc) }
    scope :has_changes, lambda {
      # Get all unique feature classes
      feature_classes = pluck(:feature_class).uniq

      # Build conditions for each feature class
      conditions = feature_classes.map do |klass|
        current_sha = compute_sha(klass)
        sanitize_sql_array(["(feature_class = ? AND (sha IS NULL OR sha != ?))", klass, current_sha])
      end

      # Combine all conditions with OR
      where(id: where(needs_fit: true).or(where(conditions.join(" OR "))).select { |f| f.adapter.respond_to?(:fit) }.map(&:id))
    }
    scope :never_applied, -> { where(applied_at: nil) }
    scope :never_fit, -> do
            fittable = where(fit_at: nil)
            fittable = fittable.select { |f| f.adapter.respond_to?(:fit) }
            where(id: fittable.map(&:id))
          end
    scope :needs_fit, -> { has_changes.or(never_applied).or(never_fit) }

    before_save :apply_defaults, if: :new_record?
    before_save :update_sha
    after_find :update_from_feature_class
    before_save :update_from_feature_class

    def feature_klass
      feature_class.constantize
    rescue NameError
      raise InvalidFeatureError, "Invalid feature class: #{feature_class}"
    end

    def adapter
      @adapter ||= feature_klass.new
    end

    def fit_reasons
      return [] if !adapter.respond_to?(:fit)

      {
        "Needs fit manually set" => read_attribute(:needs_fit),
        "Datasource was refreshed" => datasource_was_refreshed?,
        "Code changed" => code_changed?,
        "Cache expired" => cache_expired?,
      }.select { |k, v| v }.map { |k, v| k }
    end

    alias_method :refresh_reasons, :fit_reasons

    def needs_fit?
      fit_reasons.any?
    end

    def cache_expired?
      return false if refresh_every.nil? || fit_at.nil?

      fit_at < refresh_every.seconds.ago
    end

    def code_changed?
      current_sha = self.class.compute_sha(feature_class)
      sha != current_sha
    end

    def datasource_was_refreshed?
      return true if fit_at.nil?
      return false if dataset.datasource.refreshed_at.nil?

      dataset.datasource.refreshed_at > fit_at
    end

    def batchable?
      adapter.respond_to?(:batch) || (batch_size.present? &&
                                      numeric_primary_key?)
    end

    def should_be_batchable?
      adapter.respond_to?(:batch) || config.dig(:batch_size).present?
    end

    def primary_key
      pkey = config.dig(:primary_key)
      if pkey.is_a?(Array)
        pkey
      else
        [pkey]
      end
    end

    def numeric_primary_key?
      if primary_key.nil?
        return false unless should_be_batchable?
        raise "Couldn't find primary key for feature #{feature_class}, check your feature class"
      end

      dataset.raw.data(limit: 1, select: primary_key)[primary_key].to_a.flat_map { |h| h.respond_to?(:values) ? h.values : h }.all? do |value|
        case value
        when String then value.match?(/\A[-+]?\d+(\.\d+)?\z/)
        else
          value.is_a?(Numeric)
        end
      end
    end

    def build_batches
      if batchable?
        batch
      else
        [{ feature_id: id }]
      end
    end

    def batch
      reader = dataset.raw

      if adapter.respond_to?(:batch)
        array = adapter.batch(reader, self)
        min_id = array.min
        max_id = array.max
      else
        # Get all primary keys
        begin
          unless primary_key.present?
            raise "Couldn't find primary key for feature #{feature_class}, check your feature class"
          end
          df = reader.query(select: primary_key)
        rescue => e
          raise "Couldn't find primary key #{primary_key.first} for feature #{feature_class}: #{e.message}"
        end
        return [] if df.nil?

        min_id = df[primary_key.first].min
        max_id = df[primary_key.last].max
      end

      (min_id..max_id).step(batch_size).map.with_index do |batch_start, idx|
        batch_end = [batch_start + batch_size, max_id + 1].min - 1
        {
          feature_id: id,
          batch_start: batch_start,
          batch_end: batch_end,
          batch_number: feature_position,
          subbatch_number: idx,
          parent_batch_id: Random.uuid,
        }
      end
    end

    def wipe
      feature_store.wipe
    end

    def fit(features: [self], async: false)
      ordered_features = features.sort_by(&:feature_position)
      jobs = ordered_features.map(&:build_batches)

      if async
        EasyML::ComputeFeatureJob.enqueue_ordered_batches(jobs)
      else
        jobs.each do |job|
          EasyML::ComputeFeatureJob.perform(nil, job)
        end
        features.update_all(workflow_status: :ready) unless features.any?(&:failed?)
      end
    end

    # Fit a single batch, used for testing the user's feature implementation
    def fit_batch(batch_args = {})
      batch_args.symbolize_keys!
      if batch_args.key?(:batch_start)
        actually_fit_batch(batch_args)
      else
        actually_fit_batch(get_batch_args(**batch_args))
      end
    end

    # Transform a single batch, used for testing the user's feature implementation
    def transform_batch(df = nil, batch_args = {})
      if df.present?
        actually_transform_batch(df)
      else
        actually_transform_batch(build_batch(get_batch_args(**batch_args)))
      end
    end

    def get_batch_args(batch_args = {})
      unless batch_args.key?(:random)
        batch_args[:random] = true
      end
      if batch_args[:random]
        batch = build_batches.sample
      else
        batch = build_batches.first
      end
    end

    def build_batch(batch_args = {})
      batch_start = batch_args.dig(:batch_start)
      batch_end = batch_args.dig(:batch_end)

      if batch_start && batch_end
        select = needs_columns.present? ? needs_columns : nil
        filter = Polars.col(primary_key.first).is_between(batch_start, batch_end)
        params = {
          select: select,
          filter: filter,
        }.compact
      else
        params = {}
      end
      dataset.raw.query(**params)
    end

    def actually_fit_batch(batch_args = {})
      return false unless adapter.respond_to?(:fit)

      if adapter.respond_to?(:fit)
        batch_args.symbolize_keys!

        if adapter.respond_to?(:batch)
          batch_df = adapter.fit(dataset.raw, self, batch_args)
        else
          df = build_batch(batch_args)
          batch_df = adapter.fit(df, self, batch_args)
        end
      end
      if batch_df.present?
        store(batch_df)
      else
        "Feature #{feature_class}#fit should return a dataframe, received #{batch_df.class}"
      end
      batch_df
    end

    def actually_transform_batch(df)
      return nil unless df.present?
      return df if adapter.respond_to?(:fit) && feature_store.empty?

      result = adapter.transform(df, self)
      update!(applied_at: Time.current)
      result
    end

    def compute_sha
      self.class.compute_sha(feature_class)
    end

    # Position manipulation methods
    def insert
      save!
      self
    end

    def insert_where(feature_class)
      features = dataset.features.reload
      target = features.detect { |t| t.feature_class == feature_class.to_s }
      target_position = target&.feature_position
      yield target_position
      features.select { |t| target_position.nil? || t.feature_position > target_position }.each { |t| t.feature_position += 1 }
      features += [self]

      bulk_update_positions(features)
      self
    end

    def prepend
      insert_where(nil) do |_position|
        self.feature_position = 0
      end
    end

    def insert_before(feature_class)
      insert_where(feature_class) do |position|
        self.feature_position = position - 1
      end
    end

    def insert_after(feature_class)
      insert_where(feature_class) do |position|
        self.feature_position = position + 1
      end
    end

    def bump_version
      old_version = version
      write_attribute(:version, version + 1)
      feature_store.cp(old_version, version)
      self
    end

    def apply_defaults
      self.name ||= self.feature_class.demodulize.titleize
      self.version ||= 1
      self.workflow_status ||= :ready
    end

    def needs_columns
      config.dig(:needs_columns) || []
    end

    def upload_remote_files
      feature_store.upload
    end

    def feature_store
      @feature_store ||= EasyML::FeatureStore.new(self)
    end

    def upload_remote_files
      feature_store.upload_remote_files
    end

    def files
      feature_store.list_partitions
    end

    def query(filter: nil)
      feature_store.query(filter: filter)
    end

    def store(df)
      feature_store.store(df)
    end

    def batch_size
      read_attribute(:batch_size) ||
        config.dig(:batch_size) ||
        (should_be_batchable? ? 10_000 : nil)
    end

    def after_fit
      updates = {
        applied_at: Time.current,
        needs_fit: false,
      }.compact
      update!(updates)
    end

    def fully_processed?
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
      new_sha = compute_sha
      if new_sha != self.sha
        self.sha = new_sha
        self.needs_fit = true
      end
    end

    def update_from_feature_class
      if read_attribute(:batch_size) != config.dig(:batch_size)
        write_attribute(:batch_size, config.dig(:batch_size))
        self.needs_fit = true
      end

      if self.primary_key != config.dig(:primary_key)
        self.primary_key = [config.dig(:primary_key)].flatten
      end

      if new_refresh_every = config.dig(:refresh_every)
        self.refresh_every = new_refresh_every.to_i
      end
    end

    def feature_klass
      @feature_klass ||= EasyML::Features::Registry.find(feature_class.to_s).dig(:feature_class).constantize
    end

    def config
      raise "Feature not found: #{feature_class}" unless feature_klass
      feature_klass.features&.first
    end
  end

  class InvalidFeatureError < StandardError; end
end
