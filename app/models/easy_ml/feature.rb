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
        return nil unless File.exist?(path)
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
    has_many :columns, class_name: "EasyML::Column", dependent: :destroy

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
      where(id: where(needs_fit: true).or(where(conditions.join(" OR "))).map(&:id))
    }
    scope :never_applied, -> { where(applied_at: nil) }
    scope :never_fit, -> do
            fittable = where(fit_at: nil)
            fittable = fittable.select(&:fittable?)
            where(id: fittable.map(&:id))
          end
    scope :needs_fit, -> { has_changes.or(never_applied).or(never_fit).or(datasource_was_refreshed).or(where(needs_fit: true)) }
    scope :datasource_was_refreshed, -> do
            where(id: all.select(&:datasource_was_refreshed?).map(&:id))
          end
    scope :ready_to_apply, -> do
            base = where(needs_fit: false).where.not(id: has_changes.map(&:id))
            doesnt_fit = where_no_fit
            where(id: base.map(&:id).concat(doesnt_fit.map(&:id)))
          end

    scope :fittable, -> { all.select(&:fittable?) }
    scope :where_no_fit, -> { all.reject(&:fittable?) }

    before_save :apply_defaults, if: :new_record?
    before_save :update_sha
    after_find :update_from_feature_class
    before_save :update_from_feature_class
    before_destroy :wipe

    def feature_klass
      feature_class.constantize
    rescue NameError
      raise InvalidFeatureError, "Invalid feature class: #{feature_class}"
    end

    def has_code?
      feature_klass.present?
    end

    def fittable?
      adapter.respond_to?(:fit)
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
      return false unless fittable?
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

      dataset.raw.data(limit: 1, select: primary_key, all_columns: true)[primary_key].to_a.flat_map { |h| h.respond_to?(:values) ? h.values : h }.all? do |value|
        case value
        when String then value.match?(/\A[-+]?\d+(\.\d+)?\z/)
        else
          value.is_a?(Numeric)
        end
      end
    end

    def computes_columns
      unless adapter.respond_to?(:computes_columns)
        raise "Feature #{feature_class} must declare which columns it computes using the :computes_columns method"
      end
      adapter.computes_columns
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
        series = adapter.batch(reader, self)
        primary_key = series.name
      else
        primary_key = self.primary_key
      end

      EasyML::Data::Partition::Boundaries.new(
        reader.data(lazy: true, all_columns: true),
        primary_key,
        batch_size
      ).to_a.map.with_index do |partition, idx|
        {
          feature_id: id,
          batch_start: partition[:partition_start],
          batch_end: partition[:partition_end],
          batch_number: feature_position,
          subbatch_number: idx,
        }
      end
    end

    def wipe
      update(needs_fit: true) if fittable?
      feature_store.wipe
    end

    def fit(features: [self], async: false)
      ordered_features = features.sort_by(&:feature_position)
      parent_batch_id = Random.uuid
      jobs = ordered_features.select(&:fittable?).map do |feature|
        feature.build_batches.map do |batch_args|
          batch_args.merge(parent_batch_id: parent_batch_id)
        end
      end
      job_count = jobs.dup.flatten.size

      ordered_features.each(&:wipe)

      # This is very important! For whatever reason, Resque BatchJob does not properly
      # handle batch finished callbacks for batch size = 1
      if async && job_count > 1
        EasyML::ComputeFeatureJob.enqueue_ordered_batches(jobs)
      else
        jobs.each do |feature_batch|
          feature_batch.each do |batch_args|
            EasyML::ComputeFeatureJob.perform(nil, batch_args)
          end
          feature = EasyML::Feature.find(feature_batch.first.dig(:feature_id))
          feature.after_fit
        end
        dataset.after_fit_features
      end
    end

    def self.fit_one_batch(batch_id, batch_args = {})
      batch_args.symbolize_keys!
      feature_id = batch_args.dig(:feature_id)
      feature = EasyML::Feature.find(feature_id)
      dataset = feature.dataset

      # Check if any feature has failed before proceeding
      return if dataset.features.any? { |f| f.workflow_status == "failed" }

      feature.update(workflow_status: :analyzing) if feature.workflow_status == :ready
      begin
        feature.fit_batch(batch_args.merge!(batch_id: batch_id))
      rescue => e
        EasyML::Feature.transaction do
          return if dataset.reload.workflow_status == :failed

          feature.update(workflow_status: :failed)
          dataset.update(workflow_status: :failed)
          build_error_with_context(dataset, e, batch_id, feature)
        end
        raise e
      end
    end

    def self.build_error_with_context(dataset, error, batch_id, feature)
      error = EasyML::Event.handle_error(dataset, error)
      batch = feature.build_batch(batch_id: batch_id)

      # Convert any dataframes in the context to serialized form
      error.create_context(context: batch)
    end

    def self.fit_feature_failed(dataset, e)
      dataset.update(workflow_status: :failed)
      EasyML::Event.handle_error(dataset, e)
    end

    # Fit a single batch, used for testing the user's feature implementation
    def fit_batch(batch_args = {})
      batch_args.symbolize_keys!
      if batch_args.key?(:batch_start)
        actually_fit_batch(batch_args)
      else
        batch_args = get_batch_args(**batch_args)
        actually_fit_batch(batch_args)
      end
    end

    # Transform a single batch, used for testing the user's feature implementation
    def transform_batch(df = nil, batch_args = {}, inference: false)
      if df.is_a?(Polars::DataFrame)
        actually_transform_batch(df, inference: inference)
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
          sort: primary_key,
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
          df = dataset.raw
        else
          df = build_batch(batch_args)
        end
      end
      return if df.blank?

      begin
        batch_df = adapter.fit(df, self, batch_args)
      rescue => e
        raise "Feature #{feature_class}#fit failed: #{e.message}"
      end
      if batch_df.present?
        store(batch_df)
      else
        "Feature #{feature_class}#fit should return a dataframe, received #{batch_df.class}"
      end
      batch_df
    end

    def actually_transform_batch(df, inference: false)
      return nil unless df.is_a?(Polars::DataFrame)
      return df if !adapter.respond_to?(:transform) && feature_store.empty?

      df_len_was = df.shape[0]
      orig_df = df.clone
      begin
        result = adapter.transform(df, self)
      rescue => e
        raise "Feature #{feature_class}#transform failed: #{e.message}"
      end
      raise "Feature '#{name}' must return a Polars::DataFrame, got #{result.class}" unless result.is_a?(Polars::DataFrame)
      df_len_now = result.shape[0]
      missing_columns = orig_df.columns - result.columns
      raise "Feature #{feature_class}#transform: output size must match input size! Input size: #{df_len_now}, output size: #{df_len_was}." if (df_len_now != df_len_was)
      raise "Feature #{feature_class} removed #{missing_columns} columns" if missing_columns.any?
      update!(applied_at: Time.current) unless inference
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
      feature_store.bump_version(version)
      write_attribute(:version, version + 1)
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
      EasyML::FeatureStore.new(self)
    end

    delegate :files, :query, :store, :compact, to: :feature_store

    def batch_size
      read_attribute(:batch_size) ||
        config.dig(:batch_size) ||
        (should_be_batchable? ? 10_000 : nil)
    end

    def after_fit
      update_sha

      feature_store.compact if fittable?
      updates = {
        fit_at: Time.current,
        needs_fit: false,
        workflow_status: :ready,
      }.compact
      update!(updates)
    end

    def after_transform
      feature_store.compact if !fittable?
    end

    def unlock!
      feature_store.unlock!
    end

    UNCONFIGURABLE_COLUMNS = %w(
      id
      dataset_id
      sha
      applied_at
      fit_at
      created_at
      updated_at
      needs_fit
      workflow_status
      refresh_every
    )

    def to_config
      EasyML::Export::Feature.to_config(self)
    end

    def self.from_config(config, dataset, action: :create)
      EasyML::Import::Feature.from_config(config, dataset, action: action)
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
        self.needs_fit = fittable?
      end
    end

    def update_from_feature_class
      if read_attribute(:batch_size) != config.dig(:batch_size)
        write_attribute(:batch_size, config.dig(:batch_size))
        self.needs_fit = fittable?
      end

      if self.primary_key != config.dig(:primary_key)
        self.primary_key = [config.dig(:primary_key)].flatten
      end

      if new_refresh_every = config.dig(:refresh_every)
        self.refresh_every = new_refresh_every.to_i
      end
    end

    def feature_klass
      begin
        @feature_klass ||= EasyML::Features::Registry.find(feature_class.to_s).dig(:feature_class).constantize
      rescue => e
        nil
      end
    end

    def config
      raise "Feature not found: #{feature_class}" unless feature_klass
      feature_klass.features&.first
    end
  end

  class InvalidFeatureError < StandardError; end
end
