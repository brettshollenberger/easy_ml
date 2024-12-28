# == Schetuma Information
#
# Table name: easy_ml_datasets
#
#  id                      :bigint           not null, primary key
#  name                    :string           not null
#  description             :string
#  dataset_type            :string
#  status                  :string
#  version                 :string
#  datasource_id           :bigint
#  root_dir                :string
#  configuration           :json
#  num_rows                :bigint
#  workflow_status         :string
#  statistics              :json
#  preprocessor_statistics :json
#  schema                  :json
#  refreshed_at            :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
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
    has_many :columns, class_name: "EasyML::Column", dependent: :destroy
    accepts_nested_attributes_for :columns, allow_destroy: true, update_only: true

    has_many :features, dependent: :destroy, class_name: "EasyML::Feature"
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

    def self.constants
      {
        column_types: EasyML::Data::PolarsColumn::TYPE_MAP.keys.map do |type|
          { value: type.to_s, label: type.to_s.titleize }
        end,
        preprocessing_strategies: EasyML::Data::Preprocessor.constants[:preprocessing_strategies],
        feature_options: EasyML::Features::Registry.list_flat,
        splitter_constants: EasyML::Splitter.constants,
      }
    end

    def root_dir=(value)
      raise "Cannot override value of root_dir!" unless value.to_s == root_dir.to_s

      write_attribute(:root_dir, value)
    end

    def set_root_dir
      write_attribute(:root_dir, root_dir)
    end

    def root_dir
      bump_version
      EasyML::Engine.root_dir.join("datasets").join(underscored_name).join(version).to_s
    end

    def destructively_cleanup!
      FileUtils.rm_rf(root_dir) if root_dir.present?
    end

    def schema
      read_attribute(:schema) || datasource.schema
    end

    def refresh_datatypes
      return unless columns_need_refresh?

      cleanup
      datasource.reread(columns)
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

    def prepare!
      cleanup
      refresh_datasource!
      split_data
    end

    def prepare
      refresh_datasource
      split_data
    end

    def actually_refresh
      refreshing do
        split_data
        process_data
        learn
        now = UTC.now
        update(workflow_status: "ready", refreshed_at: now, updated_at: now)
        fully_reload
      end
    end

    def refresh!(async: false)
      refreshing do
        prepare!
        fit_features(async: async)
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

    def fit_features(async: false, features: self.features)
      features_to_compute = features.needs_recompute
      return if features_to_compute.empty?

      features.first.fit(features: features_to_compute, async: async)
    end

    def after_fit_features
      features.update_all(needs_recompute: false, fit_at: Time.current)
      actually_refresh
    end

    def columns_need_refresh?
      preloaded_columns.any? do |col|
        col.updated_at.present? &&
          refreshed_at.present? &&
          col.updated_at > refreshed_at
      end
    end

    def features_need_refresh?
      return true if preloaded_features.any? { |f| f.updated_at.present? && refreshed_at.present? && f.updated_at > refreshed_at }

      preloaded_features.any?(&:needs_recompute)
    end

    def refresh_reasons
      {
        "Not split" => not_split?,
        "Refreshed at is nil" => refreshed_at.nil?,
        "Columns need refresh" => columns_need_refresh?,
        "Features need refresh" => features_need_refresh?,
        "Datasource needs refresh" => datasource_needs_refresh?,
        "Datasource was refreshed" => datasource_was_refreshed?,
      }.select { |k, v| v }.map { |k, v| k }
    end

    def needs_refresh?
      refresh_reasons.any?
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

    def learn
      learn_schema
      learn_statistics
      sync_columns
    end

    def refreshing
      return false if is_history_class?

      lock_dataset do
        update(workflow_status: "analyzing")
        fully_reload
        yield
      end
    rescue StandardError => e
      update(workflow_status: "failed")
      raise e
    end

    def unlock_dataset
      Support::Lockable.query.keys.select { |key| key.include?(lock_key) }.each do |key|
        Rails.cache.delete(key)
      end
    end

    def lock_dataset
      with_lock_client do |client|
        yield
      end
    end

    def with_lock_client
      EasyML::Support::Lockable.with_lock_client(lock_key, stale_timeout: 60, resources: 1) do |client|
        yield client
      end
    end

    def lock_key
      "dataset:#{id}"
    end

    def learn_schema
      schema = data.schema.reduce({}) do |h, (k, v)|
        h.tap do
          h[k] = EasyML::Data::PolarsColumn.polars_to_sym(v)
        end
      end
      write_attribute(:schema, schema)
    end

    def learn_statistics
      update(
        statistics: EasyML::Data::StatisticsLearner.learn(raw, processed),
      )
    end

    def syncable_cols
      raw.data.schema.keys
    end

    def one_hot_cols(cols = nil)
      return [] unless preprocessing_steps && preprocessing_steps.key?(:training)

      one_hot_base_cols = preprocessing_steps[:training].select { |_k, v| v.dig(:params, :one_hot) }.keys.map(&:to_s)

      return one_hot_base_cols if cols.nil?
      return [] unless one_hot_base_cols

      cols.select do |col|
        one_hot_base_cols.any? { |base_col| col.start_with?(base_col) }
      end
    end

    def sync_columns
      return unless schema.present?

      EasyML::Column.transaction do
        col_names = syncable_cols
        existing_columns = columns.where(name: col_names)
        new_columns = col_names - existing_columns.map(&:name)
        cols_to_insert = new_columns.map do |col_name|
          EasyML::Column.new(
            name: col_name,
            dataset_id: id,
          )
        end
        EasyML::Column.import(cols_to_insert)
        columns_to_update = columns.where(name: col_names)
        stats = statistics
        cached_sample = data(limit: 100, all_columns: true)
        existing_types = existing_columns.map(&:name).zip(existing_columns.map(&:datatype)).to_h
        polars_types = cached_sample.columns.zip((cached_sample.dtypes.map do |dtype|
          EasyML::Data::PolarsColumn.polars_to_sym(dtype).to_s
        end)).to_h
        type_differences = find_type_differences(existing_types, polars_types)

        # Log type changes if any are found
        Rails.logger.info "Column type changes detected: #{type_differences}" if type_differences.any?

        columns_to_update.each do |column|
          new_polars_type = polars_types[column.name]
          existing_type = existing_types[column.name]
          schema_type = schema[column.name]

          # Keep both datatype and polars_datatype if it's an ordinal encoding case
          actual_type = if ordinal_encoding?(existing_type, new_polars_type)
              existing_type
            else
              new_polars_type
            end

          actual_schema_type = if ordinal_encoding?(existing_type, schema_type)
              existing_type
            else
              schema_type
            end

          if one_hot_cols.include?(column.name)
            base = self.raw
            processed = stats.dig("raw", column.name).dup
            processed["null_count"] = 0
            actual_schema_type = "categorical"
            actual_type = "categorical"
          else
            base = self
            processed = stats.dig("processed", column.name)
          end
          sample_values = base.send(:data, unique: true, limit: 5, select: column.name, all_columns: true)[column.name].to_a.uniq[0...5]

          column.assign_attributes(
            statistics: {
              raw: stats.dig("raw", column.name),
              processed: processed,
            },
            datatype: actual_schema_type,
            polars_datatype: actual_type,
            sample_values: sample_values,
          )
        end

        EasyML::Column.import(columns_to_update.to_a,
                              { on_duplicate_key_update: { columns: %i[statistics datatype polars_datatype
                                                                     sample_values] } })
      end
    end

    def process_data
      split_data
      fit
      normalize_all
      # alert_nulls
    end

    def needs_learn?(df)
      never_learned = columns.none?
      return true if never_learned

      new_features = features.any? { |f| f.updated_at > columns.maximum(:updated_at) }
      return true if new_features

      new_cols = df.present? ? (df.columns - columns.map(&:name)) : []

      new_cols = (new_cols - one_hot_cols(new_cols)).any?

      return true if new_cols
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

    def normalize(df = nil, split_ys: false, inference: false, all_columns: false, features: self.features)
      df = apply_features(df, features)
      df = drop_nulls(df)
      df = preprocessor.postprocess(df, inference: inference)

      # Learn will update columns, so if any features have been added
      # since the last time columns were learned, we should re-learn the schema
      learn if needs_learn?(df)
      df = apply_column_mask(df, inference: inference) unless all_columns
      df, = processed.split_features_targets(df, true, target) if split_ys
      df
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

    def processed?
      !should_split?
    end

    def decode_labels(ys, col: nil)
      preprocessor.decode_labels(ys, col: col.nil? ? target : col)
    end

    def preprocessing_steps
      return if columns.nil? || (columns.respond_to?(:empty?) && columns.empty?)
      return @preprocessing_steps if @preprocessing_steps.present?

      training = standardize_preprocessing_steps(:training)
      inference = standardize_preprocessing_steps(:inference)

      @preprocessing_steps = {
        training: training,
        inference: inference,
      }.compact.deep_symbolize_keys
    end

    def preprocessor
      @preprocessor ||= initialize_preprocessor
      return @preprocessor if @preprocessor.preprocessing_steps == preprocessing_steps

      @preprocessor = initialize_preprocessor
    end

    def target
      @target ||= preloaded_columns.find(&:is_target)&.name
    end

    def drop_cols
      @drop_cols ||= preloaded_columns.select(&:hidden).map(&:name)
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
      one_hot_cats = preprocessor.statistics.dup
        .select { |k, _v| one_hots.map(&:name).include?(k.to_s) }
        .to_h.reduce({}) do |h, (k, v)|
        h.tap do
          h[k] = v[:allowed_categories].sort.concat(["other"]).map { |val| "#{k}_#{val}" }
        end
      end

      # Map columns to names, handling one_hot expansion
      scope.sort_by(&:id).flat_map do |col|
        if col.one_hot?
          one_hot_cats[col.name.to_sym]
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
      return unless processed?

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

    private

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
      refresh_datatypes
      initialize_splits
    end

    def refresh_datasource!
      datasource.reload.refresh!
      refresh_datatypes
      initialize_splits
    end

    def normalize_all
      processed.cleanup

      SPLIT_ORDER.each do |segment|
        df = raw.read(segment)
        processed_df = normalize(df, all_columns: true)
        processed.save(segment, processed_df)
      end
      @normalized = true
    end

    def drop_nulls(df)
      return df if drop_if_null.nil? || drop_if_null.empty?

      drop = (df.columns & drop_if_null)
      return df if drop.empty?

      df.drop_nulls(subset: drop)
    end

    def load_data(segment, **kwargs, &block)
      if processed?
        processed.load_data(segment, **kwargs, &block)
      else
        raw.load_data(segment, **kwargs, &block)
      end
    end

    def fit(xs = nil)
      xs = raw.train(all_columns: true) if xs.nil?

      preprocessor.fit(xs)
      self.preprocessor_statistics = preprocessor.statistics
    end

    # log_method :fit, "Learning statistics", verbose: true

    def split_data!
      split_data(force: true)
    end

    def split_data(force: false)
      return unless force || should_split?

      cleanup
      features = self.features.ordered.load
      splitter.split(datasource) do |train_df, valid_df, test_df|
        [:train, :valid, :test].zip([train_df, valid_df, test_df]).each do |segment, df|
          df = apply_features(df, features) if features.any?
          raw.save(segment, df)
        end
      end
    end

    def should_split?
      needs_refresh?
    end

    def apply_features(df, features = self.features)
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

    def initialize_preprocessor
      EasyML::Data::Preprocessor.new(
        directory: Pathname.new(root_dir).append("preprocessor"),
        preprocessing_steps: preprocessing_steps,
      ).tap do |preprocessor|
        preprocessor.statistics = preprocessor_statistics
      end
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

    def find_type_differences(existing_types, polars_types)
      differences = {}

      polars_types.each do |column_name, polars_type|
        existing_type = existing_types[column_name]
        next if existing_type.nil?
        next if existing_type == polars_type

        # Skip reporting differences for ordinal encoding cases
        next if ordinal_encoding?(existing_type, polars_type)

        differences[column_name] = {
          old: existing_type,
          new: polars_type,
        }
      end

      differences
    end

    def ordinal_encoding?(old_type, new_type)
      string_like_types = %w[text string categorical]
      new_type == "integer" && string_like_types.include?(old_type)
    end

    def underscored_name
      name.gsub(/\s{2,}/, " ").gsub(/\s/, "_").downcase
    end
  end
end
