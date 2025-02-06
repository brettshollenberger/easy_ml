# == Schema Information
#
# Table name: easy_ml_datasets
#
#  id                  :bigint           not null, primary key
#  name                :string           not null
#  description         :string
#  dataset_type        :string
#  status              :string
#  version             :string
#  datasource_id       :bigint
#  root_dir            :string
#  configuration       :json
#  num_rows            :bigint
#  workflow_status     :string
#  statistics          :json
#  schema              :json
#  refreshed_at        :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  last_datasource_sha :string
#
module EasyML
  class Dataset < ActiveRecord::Base
    self.table_name = "easy_ml_datasets"
    include EasyML::Concerns::Configurable
    include EasyML::Concerns::Versionable
    include Historiographer::Silent
    historiographer_mode :snapshot_only

    enum workflow_status: {
      analyzing: "analyzing",
      ready: "ready",
      failed: "failed",
    }

    SPLIT_ORDER = %i[train valid test]

    self.filter_attributes += %i[configuration statistics schema]

    validates :name, presence: true
    belongs_to :datasource, class_name: "EasyML::Datasource"

    has_many :models, class_name: "EasyML::Model"
    has_many :columns, class_name: "EasyML::Column", dependent: :destroy, extend: EasyML::ColumnList
    accepts_nested_attributes_for :columns, allow_destroy: true, update_only: true

    has_many :features, dependent: :destroy, class_name: "EasyML::Feature", extend: EasyML::FeatureList
    accepts_nested_attributes_for :features, allow_destroy: true

    has_many :events, as: :eventable, class_name: "EasyML::Event", dependent: :destroy

    before_destroy :destructively_cleanup!

    delegate :new_data_available?, :synced?, :stale?, to: :datasource
    delegate :train, :test, :valid, to: :split
    delegate :splits, to: :splitter

    has_one :splitter, class_name: "EasyML::Splitter", dependent: :destroy, inverse_of: :dataset

    accepts_nested_attributes_for :splitter,
                                  allow_destroy: true,
                                  reject_if: :all_blank

    validates :datasource, presence: true

    add_configuration_attributes :remote_files

    after_find :download_remote_files
    after_create :refresh_async
    after_initialize do
      bump_version unless version.present?
      write_attribute(:workflow_status, :ready) if workflow_status.nil?
    end
    before_save :set_root_dir
    before_validation :filter_duplicate_features

    def self.constants
      {
        column_types: EasyML::Data::PolarsColumn::TYPE_MAP.keys.map do |type|
          { value: type.to_s, label: type.to_s.titleize }
        end,
        preprocessing_strategies: EasyML::Column::Imputers.constants[:preprocessing_strategies],
        feature_options: EasyML::Features::Registry.list_flat,
        splitter_constants: EasyML::Splitter.constants,
      }
    end

    def root_dir=(value)
      raise "Cannot override value of root_dir!" unless value.to_s == root_dir.to_s

      write_attribute(:root_dir, value)
    end

    def set_root_dir
      bump_version
      write_attribute(:root_dir, default_root_dir)
    end

    def default_root_dir
      File.join("datasets", underscored_name, version).to_s
    end

    def root_dir
      relative_dir = read_attribute(:root_dir) || default_root_dir

      EasyML::Engine.root_dir.join(relative_dir).to_s
    end

    def destructively_cleanup!
      FileUtils.rm_rf(root_dir) if root_dir.present?
    end

    def schema
      read_attribute(:schema) || datasource.schema
    end

    def processed_schema
      processed.data(limit: 1)&.schema || raw.data(limit: 1)&.schema
    end

    def num_rows
      if datasource&.num_rows.nil?
        datasource.after_sync
      end
      datasource&.num_rows
    end

    def refresh_async
      return if analyzing?

      update(workflow_status: "analyzing")
      EasyML::RefreshDatasetJob.perform_later(id)
    end

    def best_segment
      [processed, raw].detect do |segment|
        segment.send(:data, all_columns: true, limit: 1)&.columns
      end
    end

    def raw
      return @raw if @raw && @raw.dataset

      @raw = initialize_split("raw")
    end

    def processed
      return @processed if @processed && @processed.dataset

      @processed = initialize_split("processed")
    end

    def bump_versions(version)
      self.version = version

      @raw = raw.cp(version)
      @processed = processed.cp(version)
      features.each(&:bump_version)

      save
    end

    def refreshed_datasource?
      last_datasource_sha_changed?
    end

    def prepare!
      cleanup
      refresh_datasource!
      split_data
      process_data
    end

    def prepare
      refresh_datasource
      split_data
      process_data
    end

    def actually_refresh
      refreshing do
        learn(delete: false) # After syncing datasource, learn new statistics + sync columns
        process_data
        fully_reload
        learn
        learn_statistics(type: :processed) # After processing data, we learn any new statistics
        now = UTC.now
        update(workflow_status: "ready", refreshed_at: now, updated_at: now)
        fully_reload
      end
    end

    def refresh!(async: false)
      refreshing do
        prepare!
        fit_features!(async: async)
      end
      after_fit_features unless async
    end

    def refresh(async: false)
      return refresh_async if async

      refreshing do
        prepare
        fit_features(async: async)
      end
      after_fit_features unless async
    end

    def fit_features!(async: false, features: self.features)
      fit_features(async: async, features: features, force: true)
    end

    def fit_features(async: false, features: self.features, force: false)
      features_to_compute = force ? features : features.needs_fit
      return if features_to_compute.empty?

      features.first.fit(features: features_to_compute, async: async)
    end

    def after_fit_features
      unlock!
      reload
      return if failed?

      features.update_all(needs_fit: false, fit_at: Time.current)
      actually_refresh
    end

    def columns_need_refresh
      preloaded_columns.select do |col|
        col.updated_at.present? &&
          refreshed_at.present? &&
          col.updated_at > refreshed_at
      end
    end

    def columns_need_refresh?
      columns_need_refresh.any?
    end

    def features_need_fit
      preloaded_features.select do |f|
        (f.updated_at.present? && refreshed_at.present? && f.updated_at > refreshed_at) ||
          f.needs_fit?
      end
    end

    def features_need_fit?
      features_need_fit.any?
    end

    # Some of these are expensive to calculate, so we only want to include
    # them in the refresh reasons if they are actually needed.
    #
    # During dataset_serializer for instance, we don't want to check s3,
    # we only do that during background jobs.
    #
    # So yes this is an annoying way to structure a method, but it's helpful for performance
    #
    def refresh_reasons(exclude: [])
      {
        not_split: {
          name: "Not split",
          check: -> { not_split? },
        },
        refreshed_at_is_nil: {
          name: "Refreshed at is nil",
          check: -> { refreshed_at.nil? },
        },
        columns_need_refresh: {
          name: "Columns need refresh",
          check: -> { columns_need_refresh? },
        },
        features_need_fit: {
          name: "Features need fit",
          check: -> { features_need_fit? },
        },
        datasource_needs_refresh: {
          name: "Datasource needs refresh",
          check: -> { datasource_needs_refresh? },
        },
        refreshed_datasource: {
          name: "Refreshed datasource",
          check: -> { refreshed_datasource? },
        },
        datasource_was_refreshed: {
          name: "Datasource was refreshed",
          check: -> { datasource_was_refreshed? },
        },
      }.except(*exclude).select do |k, config|
        config[:check].call
      end.map do |k, config|
        config[:name]
      end
    end

    def needs_refresh?(exclude: [])
      refresh_reasons(exclude: exclude).any?
    end

    def processed?
      !needs_refresh?
    end

    def not_split?
      processed.split_at.nil? || raw.split_at.nil?
    end

    def datasource_needs_refresh?
      datasource&.needs_refresh?
    end

    def datasource_was_refreshed?
      raw.split_at.present? && raw.split_at < datasource.last_updated_at
    end

    def learn(delete: true)
      learn_schema
      columns.sync(delete: delete)
    end

    def refreshing
      begin
        return false if is_history_class?
        unlock! unless analyzing?

        lock_dataset do
          update(workflow_status: "analyzing")
          fully_reload
          yield
        ensure
          unlock!
        end
      rescue => e
        update(workflow_status: "failed")
        e.backtrace.grep(/easy_ml/).each do |line|
          puts line
        end
        raise e
      end
    end

    def unlock!
      Support::Lockable.unlock!(lock_key)
    end

    def locked?
      Support::Lockable.locked?(lock_key)
    end

    def lock_dataset
      data = processed.data(limit: 1).to_a.any? ? processed.data : raw.data
      with_lock do |client|
        yield
      end
    end

    def with_lock
      EasyML::Support::Lockable.with_lock(lock_key, stale_timeout: 60, resources: 1) do |client|
        yield client
      end
    end

    def lock_key
      "dataset:#{id}"
    end

    def learn_schema
      data = processed.data(limit: 1).to_a.any? ? processed.data : raw.data
      return nil if data.nil?

      schema = data.schema.reduce({}) do |h, (k, v)|
        h.tap do
          h[k] = EasyML::Data::PolarsColumn.polars_to_sym(v)
        end
      end
      write_attribute(:schema, schema)
    end

    def learn_statistics(type: :raw, computed: false)
      columns.learn(type: type, computed: computed)
      update(
        statistics: columns.reload.statistics,
      )
    end

    def statistics
      (read_attribute(:statistics) || {}).with_indifferent_access
    end

    def process_data
      fit
      normalize_all
    end

    def needs_learn?
      return true if columns_need_refresh?

      never_learned = columns.none?
      return true if never_learned

      new_features = features.any? { |f| f.updated_at > columns.maximum(:updated_at) }
      return true if new_features

      df = raw.query(limit: 1)
      new_cols = df.present? ? (df.columns - columns.map(&:name)) : []
      new_cols = columns.syncable

      return true if new_cols.any?
    end

    def compare_datasets(df, df_was)
      # Step 1: Check if the entire dataset is identical
      if df == df_was
        return "The datasets are identical."
      end

      # Step 2: Identify columns with differences
      differing_columns = df.columns.select do |column|
        df[column] != df_was[column]
      end

      # Step 3: Find row-level differences for each differing column
      differences = {}
      differing_columns.each do |column|
        mask = df[column] != df_was[column]
        differing_rows = df[mask][column].zip(df_was[mask][column]).map.with_index do |(df_value, df_was_value), index|
          { row_index: index, df_value: df_value, df_was_value: df_was_value }
        end

        differences[column] = differing_rows
      end

      { differing_columns: differing_columns, differences: differences }
    end

    def validate_input(df)
      fields = missing_required_fields(df)
      return fields.empty?, fields
    end

    def normalize(df = nil, split_ys: false, inference: false, all_columns: false, features: self.features)
      df = apply_missing_features(df, inference: inference)
      df = drop_nulls(df)
      df = columns.transform(df, inference: inference)
      df = apply_features(df, features)
      df = columns.transform(df, inference: inference, computed: true)
      df = apply_column_mask(df, inference: inference) unless all_columns
      df, = processed.split_features_targets(df, true, target) if split_ys
      df
    end

    def missing_required_fields(df)
      desc_df = df.describe

      # Get the 'null_count' row
      null_count_row = desc_df.filter(desc_df[:describe] == "null_count")

      # Select columns with non-zero null counts
      columns_with_nulls = null_count_row.columns.select do |col|
        null_count_row[col][0].to_i > 0
      end

      # This is a history class, because this only occurs on prediction
      required_columns = columns.current.required.map(&:name)
      required_columns.select do |col|
        columns_with_nulls.include?(col) || df.columns.map(&:to_s).exclude?(col.to_s)
      end
    end

    # Filter data using Polars predicates:
    # dataset.data(filter: Polars.col("CREATED_DATE") > EST.now - 2.days)
    # dataset.data(limit: 10)
    # dataset.data(select: ["column1", "column2", "column3"], limit: 10)
    # dataset.data(split_ys: true)
    # dataset.data(all_columns: true) # Include all columns, even ones we SHOULDN'T train on (e.g. drop_cols). Be very careful! This is for data analysis purposes ONLY!
    #
    def train(**kwargs, &block)
      load_data(:train, **kwargs, &block)
    end

    def valid(**kwargs, &block)
      load_data(:valid, **kwargs, &block)
    end

    def test(**kwargs, &block)
      load_data(:test, **kwargs, &block)
    end

    def data(**kwargs, &block)
      load_data(:all, **kwargs, &block)
    end

    alias_method :query, :data

    def cleanup
      raw.cleanup
      processed.cleanup
    end

    def check_nulls(data_type = :processed)
      result = SPLIT_ORDER.each_with_object({}) do |segment, acc|
        segment_result = { nulls: {}, total: 0 }

        data_source = data_type == :raw ? raw : processed
        data_source.read(segment) do |df|
          df_nulls = null_check(df)
          df.columns.each do |column|
            segment_result[:nulls][column] ||= { null_count: 0, total_count: 0 }
            segment_result[:nulls][column][:null_count] += df_nulls[column][:null_count] if df_nulls && df_nulls[column]
            segment_result[:nulls][column][:total_count] += df.height
          end
        end

        segment_result[:nulls].each do |column, counts|
          percentage = (counts[:null_count].to_f / counts[:total_count] * 100).round(1)
          acc[column] ||= {}
          acc[column][segment] = percentage
        end
      end

      # Remove columns that have no nulls across all segments
      result.reject! { |_, v| v.values.all?(&:zero?) }

      result.empty? ? nil : result
    end

    def decode_labels(ys, col: nil)
      if col.nil?
        col = target
      end
      preloaded_columns.find_by(name: col).decode_labels(ys)
    end

    def preprocessing_steps
      return {} if preloaded_columns.nil? || (preloaded_columns.respond_to?(:empty?) && preloaded_columns.empty?)
      return @preprocessing_steps if @preprocessing_steps.present?

      training = standardize_preprocessing_steps(:training)
      inference = standardize_preprocessing_steps(:inference)

      @preprocessing_steps = {
        training: training,
        inference: inference,
      }.compact.deep_symbolize_keys
    end

    def target
      @target ||= preloaded_columns.find(&:is_target)&.name
    end

    def date_column
      @date_column ||= preloaded_columns.find(&:is_date_column?)
    end

    def drop_cols
      @drop_cols ||= preloaded_columns.select(&:hidden).flat_map(&:aliases)
    end

    def drop_if_null
      @drop_if_null ||= preloaded_columns.select(&:drop_if_null).map(&:name)
    end

    def col_order(inference: false)
      # Filter preloaded columns in memory
      scope = preloaded_columns.reject(&:hidden)
      scope = scope.reject(&:is_target) if inference

      # Get one_hot columns for category mapping
      one_hots = scope.select(&:one_hot?)
      one_hot_cats = columns.allowed_categories.symbolize_keys

      # Map columns to names, handling one_hot expansion
      scope.sort_by(&:id).flat_map do |col|
        if col.one_hot?
          one_hot_cats[col.name.to_sym].map do |cat|
            "#{col.name}_#{cat}"
          end
        else
          col.name
        end
      end
    end

    def column_mask(df, inference: false)
      cols = df.columns & col_order(inference: inference)
      cols.sort_by { |col| col_order.index(col) }
    end

    def apply_column_mask(df, inference: false)
      df[column_mask(df, inference: inference)]
    end

    def apply_missing_features(df, inference: false, include_one_hots: false)
      return df unless inference

      missing_features = (col_order(inference: inference) - df.columns).compact
      unless include_one_hots
        missing_features -= columns.one_hots.flat_map(&:virtual_columns) unless include_one_hots
        missing_features += columns.one_hots.map(&:name) - df.columns
      end
      df.with_columns(missing_features.map { |f| Polars.lit(nil).alias(f) })
    end

    def drop_columns(all_columns: false)
      if all_columns
        []
      else
        drop_cols
      end
    end

    def files
      [raw, processed].flat_map(&:files)
    end

    def load_dataset
      download_remote_files
    end

    def upload_remote_files
      return if !needs_refresh?

      processed.upload.tap do
        features.each(&:upload_remote_files)
        features.each(&:save)
        save
      end
    end

    def reload(*args)
      # Call the original reload method
      super(*args)
      # Reset preloaded instance variables
      @preloaded_columns = nil
      @preloaded_features = nil
      self
    end

    def after_create_columns
      apply_date_splitter_config
    end

    private

    def apply_date_splitter_config
      return unless splitter.date_splitter?

      set_date_column(splitter.date_col)
    end

    def preloaded_features
      @preloaded_features ||= features.includes(:dataset).load
    end

    def preloaded_columns
      @preloaded_columns ||= columns.load
    end

    def download_remote_files
      return unless is_history_class? # Only historical datasets need this
      return if processed.present? && processed.data

      processed.download
    end

    def initialize_splits
      @raw = nil
      @processed = nil
      raw
      processed
    end

    def initialize_split(type)
      return unless datasource.present?

      args = { dataset: self, datasource: datasource }
      case split_type.to_s
      when EasyML::Data::Splits::InMemorySplit.to_s
        split_type.new(**args)
      when EasyML::Data::Splits::FileSplit.to_s
        split_type.new(**args.merge(
                         dir: Pathname.new(root_dir).append("files/splits/#{type}").to_s,
                       ))
      end
    end

    def split_type
      datasource.in_memory? ? EasyML::Data::Splits::InMemorySplit : EasyML::Data::Splits::FileSplit
    end

    def refresh_datasource
      datasource.reload.refresh
      after_refresh_datasource
    end

    def refresh_datasource!
      datasource.reload.refresh!
      after_refresh_datasource
    end

    def after_refresh_datasource
      update(last_datasource_sha: datasource.sha)
      initialize_splits
    end

    def normalize_all
      processed.cleanup

      SPLIT_ORDER.each do |segment|
        df = raw.read(segment)
        learn_computed_columns(df) if segment == :train
        processed_df = normalize(df, all_columns: true)
        processed.save(segment, processed_df)
      end
      @normalized = true
    end

    def learn_computed_columns(df)
      return unless features.ready_to_apply.any?

      df = df.clone
      df = apply_features(df)
      processed.save(:train, df)
      learn(delete: false)
      learn_statistics(type: :processed, computed: true)
      processed.cleanup
    end

    def drop_nulls(df)
      return df if drop_if_null.nil? || drop_if_null.empty?

      drop = (df.columns & drop_if_null)
      return df if drop.empty?

      df.drop_nulls(subset: drop)
    end

    # Pass refresh: false for frontend views so we don't query S3 during web requests
    def load_data(segment, **kwargs, &block)
      needs_refresh = kwargs.key?(:refresh) ? kwargs[:refresh] : needs_refresh?
      kwargs.delete(:refresh)

      if needs_refresh
        processed.load_data(segment, **kwargs, &block)
      else
        raw.load_data(segment, **kwargs, &block)
      end
    end

    def fit
      learn_statistics(type: :raw)
    end

    # log_method :fit, "Learning statistics", verbose: true

    def split_data!
      split_data(force: true)
    end

    def split_data(force: false)
      return unless force || needs_refresh?

      cleanup
      splitter.split(datasource) do |train_df, valid_df, test_df|
        [:train, :valid, :test].zip([train_df, valid_df, test_df]).each do |segment, df|
          raw.save(segment, df)
        end
      end
    end

    def filter_duplicate_features
      return unless attributes["features_attributes"].present?

      existing_feature_names = features.pluck(:name)
      attributes["features_attributes"].each do |_, attrs|
        # Skip if it's marked for destruction or is an existing record
        next if attrs["_destroy"] == "1" || attrs["id"].present?

        # Reject the feature if it would be a duplicate
        attrs["_destroy"] = "1" if existing_feature_names.include?(attrs["name"])
      end
    end

    def set_date_column(column_name)
      return unless column_name.present?

      columns.find_by(name: column_name).update(is_date_column: true)
    end

    def apply_features(df, features = self.features)
      features = features.ready_to_apply
      if features.nil? || features.empty?
        df
      else
        # Eager load all features with their necessary associations in one query
        if features.is_a?(Array) # Used for testing (feature.transform_batch)
          features_to_apply = features
        else
          features_to_apply = features.ordered.includes(dataset: :datasource).to_a
        end

        # Preload all feature SHAs in one batch
        feature_classes = features_to_apply.map(&:feature_class).uniq
        shas = feature_classes.map { |klass| [klass, Feature.compute_sha(klass)] }.to_h

        # Apply features in sequence with preloaded data
        features_to_apply.reduce(df) do |acc_df, feature|
          # Set SHA without querying
          feature.instance_variable_set(:@current_sha, shas[feature.feature_class])

          result = feature.transform_batch(acc_df)

          unless result.is_a?(Polars::DataFrame)
            raise "Feature '#{feature.name}' must return a Polars::DataFrame, got #{result.class}"
          end

          result
        end
      end
    end

    def standardize_preprocessing_steps(type)
      columns.map(&:name).zip(columns.map do |col|
        col.preprocessing_steps&.dig(type)
      end).to_h.compact.reject { |_k, v| v["method"] == "none" }
    end

    def fully_reload
      return unless persisted?

      base_vars = self.class.new.instance_variables
      dirty_vars = (instance_variables - base_vars)
      in_memory_classes = [EasyML::Data::Splits::InMemorySplit]
      dirty_vars.each do |ivar|
        value = instance_variable_get(ivar)
        remove_instance_variable(ivar) unless in_memory_classes.any? { |in_memory_class| value.is_a?(in_memory_class) }
      end
      reload
    end

    def underscored_name
      name.gsub(/\s{2,}/, " ").gsub(/\s/, "_").downcase
    end
  end
end
