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
#  raw_schema          :jsonb
#  view_class          :string
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
    validate :view_class_exists, if: -> { view_class.present? }

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
        embedding_constants: EasyML::Data::Embeddings::Embedder.constants,
        available_views: Rails.root.join("app/datasets").glob("*.rb").map { |f| 
          name = f.basename(".rb").to_s.camelize
          { value: name, label: name.titleize }
        }
      }
    end

    UNCONFIGURABLE_COLUMNS = %w(
      id
      statistics
      root_dir
      created_at
      updated_at
      refreshed_at
      sha
      datasource_id
      last_datasource_sha
    )

    def to_config
      EasyML::Export::Dataset.to_config(self)
    end

    def self.from_config(json_config, action: nil, dataset: nil)
      EasyML::Import::Dataset.from_config(json_config, action: action, dataset: dataset)
    end

    def root_dir=(value)
      raise "Cannot override value of root_dir!" unless value.to_s == root_dir.to_s

      write_attribute(:root_dir, value)
    end

    def dir
      root_dir
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

    def as_json
      @serializing = true
      super.tap do
        @serializing = false
      end
    end

    def schema
      return @schema if @schema
      return read_attribute(:schema) if @serializing

      schema = read_attribute(:schema) || materialized_view&.schema || datasource.schema || datasource.after_sync.schema
      schema = set_schema(schema)
      @schema = EasyML::Data::PolarsSchema.deserialize(schema)
    end

    def raw_schema
      return @raw_schema if @raw_schema
      return read_attribute(:raw_schema) if @serializing

      raw_schema = read_attribute(:raw_schema) || materialized_view&.schema || datasource.schema || datasource.after_sync.schema
      raw_schema = set_raw_schema(raw_schema)
      @raw_schema = EasyML::Data::PolarsSchema.deserialize(raw_schema)
    end

    def set_schema(schema)
      write_attribute(:schema, EasyML::Data::PolarsSchema.serialize(schema))
    end

    def set_raw_schema(raw_schema)
      write_attribute(:raw_schema, EasyML::Data::PolarsSchema.serialize(raw_schema))
    end

    def processed_schema
      processed.data(limit: 1, lazy: true)&.schema || raw.data(limit: 1)&.schema
    end

    def num_rows
      if datasource&.num_rows.nil?
        datasource.after_sync
      end

      if materialized_view.present?
        materialized_view.shape[0]
      else
        datasource&.num_rows
      end
    end

    def abort!
      EasyML::Reaper.kill(EasyML::RefreshDatasetJob, id)
      update(workflow_status: :ready)
      unlock!
      features.update_all(needs_fit: true, workflow_status: "ready")
      features.each(&:wipe)
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
      original_version = self.version
      self.version = version

      @raw = raw.cp(dir.gsub(original_version, version))
      @processed = processed.cp(dir.gsub(original_version, version))
      save.tap do
        features.each { |feature| feature.bump_version(original_version, version) }
        EasyML::Feature.import(features.to_a, on_duplicate_key_update: [:version])
      end
    end

    def refreshed_datasource?
      last_datasource_sha_changed?
    end

    def prepare_features
      features.update_all(workflow_status: "ready")
    end

    def view_class_exists
      begin
        view_class.constantize
      rescue NameError
        errors.add(:view_class, "must be a valid class name")
      end
    end

    def materialize_view(df)
      df
    end

    def materialized_view
      return @materialized_view if @materialized_view

      original_df = datasource.data
      if view_class.present?
        @materialized_view = view_class.constantize.new.materialize_view(original_df)
      else
        @materialized_view = materialize_view(original_df)
      end
    end

    def prepare!
      prepare_features
      cleanup
      refresh_datasource!
      split_data
      fit
    end

    def prepare
      prepare_features
      refresh_datasource
      split_data
      fit
    end

    def actually_refresh
      refreshing do
        fit
        normalize_all
        fully_reload
        learn
        learn_statistics(type: :processed) # After processing data, we learn any new statistics
        fully_reload
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
    end

    def refresh(async: false)
      return refresh_async if async

      refreshing do
        prepare
        fit_features(async: async)
      end
    end

    def fit_features!(async: false, features: self.features)
      fit_features(async: async, features: features, force: true)
    end

    def fit_features(async: false, features: self.features, force: false)
      features_to_compute = force ? features : features.needs_fit
      return after_fit_features if features_to_compute.empty?

      features.first.fit(features: features_to_compute, async: async)
    end

    def after_fit_features
      unlock!
      reload
      return if failed?

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
    def refresh_reasons(except: [])
      RefreshReasons.new(self).check(except: except)
    end

    def needs_refresh?(except: [])
      refresh_reasons(except: except).any?
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
        end
      rescue => e
        update(workflow_status: "failed")
        EasyML::Event.handle_error(self, e)
        raise e
      ensure
        unlock!
      end
    end

    def unlock!
      Support::Lockable.unlock!(lock_key)
      features.each(&:unlock!)
      true
    end

    def locked?
      Support::Lockable.locked?(lock_key)
    end

    def lock_dataset
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
      split = processed.data(limit: 1).to_a.any? ? :processed : :raw
      return nil if split.nil?

      schema = send(split).data(all_columns: true, lazy: true).schema
      set_schema(schema)
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

    def needs_learn?
      return true if view_class.present?
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
      df = apply_missing_columns(df, inference: inference)
      df = transform_columns(df, inference: inference, encode: false)
      df = apply_cast(df)
      df = apply_features(df, features, inference: inference)
      df = apply_cast(df) if inference
      df = transform_columns(df, inference: inference)
      df = apply_column_mask(df, inference: inference) unless all_columns
      df = drop_nulls(df) unless inference
      df, = processed.split_features_targets(df, true, target) if split_ys
      df
    end

    def transform_columns(df, inference: false, encode: true)
      columns.transform(df, inference: inference, encode: encode)
    end

    def apply_cast(df)
      columns.apply_cast(df)
    end

    # Massage out one-hot cats to their canonical name
    #
    # Takes: ["Sex_male", "Sex_female", "Embarked_c", "PassengerId"]
    # Returns: ["Embarked", "Sex", "PassengerId"]
    def regular_columns(col_list)
      one_hot_cats = columns.allowed_categories.invert.reduce({}) do |h, (k, v)|
        h.tap do
          k.each do |k2|
            h["#{v}_#{k2}"] = v
          end
        end
      end

      col_list.map do |col|
        one_hot_cats.key?(col) ? one_hot_cats[col] : col
      end.uniq.sort
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

    def dataset_primary_key
      @dataset_primary_key ||= preloaded_columns.find(&:is_primary_key)&.name
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
      preloaded_columns.col_order(inference: inference)
    end

    def column_mask(df, inference: false)
      cols = df.columns & col_order(inference: inference)
      cols.sort_by { |col| col_order.index(col) }
    end

    def apply_column_mask(df, inference: false)
      df[column_mask(df, inference: inference)]
    end

    def apply_missing_columns(df, inference: false)
      return df unless inference

      required_cols = col_order(inference: inference).compact.uniq
      columns.one_hots.each do |one_hot|
        virtual_columns = one_hot.virtual_columns
        if virtual_columns.all? { |vc| df.columns.include?(vc) }
          required_cols -= virtual_columns
        else
          required_cols += [one_hot.name]
        end
      end
      missing_columns = required_cols - df.columns
      df.with_columns(missing_columns.map { |f| Polars.lit(nil).alias(f) })
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

    def list_nulls(input = nil, list_raw = false)
      input = data(lazy: true) if input.nil?

      case input
      when Polars::DataFrame
        input = input.lazy
      when String, Symbol
        input = input.to_sym
        input = send(input).data(lazy: true)
      end
      col_list = EasyML::Data::DatasetManager.list_nulls(input)
      list_raw ? col_list : regular_columns(col_list)
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
                         dir: Pathname.new(root_dir).join("files/splits/#{type}").to_s,
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
      schema
      save
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
      features.select { |f| !f.fittable? }.each(&:after_transform)
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

      if !needs_refresh
        processed.load_data(segment, **kwargs, &block)
      else
        raw.load_data(segment, **kwargs, &block)
      end
    end

    def fit
      learn(delete: false)
      learn_statistics(type: :raw)
    end

    def split_data!
      split_data(force: true)
    end

    def split_data(force: false)
      return unless force || needs_refresh?

      cleanup

      train_df, valid_df, test_df = splitter.split(self)
      raw.save(:train, train_df)
      raw.save(:valid, valid_df)
      raw.save(:test, test_df)

      raw_schema # Set if not already set
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

    def apply_features(df, features = self.features, inference: false)
      features = inference ? preloaded_features : features.ready_to_apply
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

          result = feature.transform_batch(acc_df, inference: inference)

          result
        end
      end
    end

    def standardize_preprocessing_steps(type)
      columns.map(&:name).zip(columns.map do |col|
        col.preprocessing_steps&.dig(type)
      end).to_h.compact.reject { |_k, v| v["method"] == "none" }
    end

    def underscored_name
      name.gsub(/\s{2,}/, " ").gsub(/\s/, "_").downcase
    end

    TIME_METHODS = %w(
      refresh
      prepare_features
      refresh_datasource
      split_data
      fit
      normalize_all
      learn
      learn_statistics
      fit_features
    )
    include EasyML::Timing
    TIME_METHODS.each do |method|
      measure_method_timing method
    end
  end
end
