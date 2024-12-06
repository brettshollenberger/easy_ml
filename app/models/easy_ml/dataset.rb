# == Schema Information
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
      locked: "locked"
    }

    SPLIT_ORDER = %i[train valid test]

    self.filter_attributes += %i[configuration statistics schema]

    validates :name, presence: true
    belongs_to :datasource, class_name: "EasyML::Datasource"

    has_many :models, class_name: "EasyML::Model"
    has_many :columns, class_name: "EasyML::Column", dependent: :destroy
    accepts_nested_attributes_for :columns, allow_destroy: true, update_only: true

    has_many :transforms, dependent: :destroy, class_name: "EasyML::Transform"
    accepts_nested_attributes_for :transforms, allow_destroy: true

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
    after_initialize do
      bump_version unless version.present?
    end
    before_save :set_root_dir

    def self.constants
      {
        column_types: EasyML::Data::PolarsColumn::TYPE_MAP.keys.map do |type|
          { value: type.to_s, label: type.to_s.titleize }
        end,
        preprocessing_strategies: EasyML::Data::Preprocessor.constants[:preprocessing_strategies],
        transform_options: EasyML::Transforms::Registry.list_flat
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

    def num_rows
      datasource&.num_rows
    end

    def refresh_async
      update(workflow_status: "analyzing")
      EasyML::RefreshDatasetWorker.perform_async(id)
    end

    def raw
      return @raw if @raw && @raw.dataset

      @raw = initialize_split("raw")
    end

    def processed
      return @processed if @processed && @processed.dataset

      @processed = initialize_split("processed")
    end

    def lock
      upload_remote_files
      save
    end

    def bump_versions(version)
      self.version = version

      @raw = raw.cp(version)
      @processed = processed.cp(version)
      @locked = nil

      save
    end

    def locked?
      false
    end

    def locked
      return @locked if @locked

      @locked = initialize_split("locked")
    end

    def refresh!
      refreshing do
        cleanup
        refresh_datasource!
        process_data
      end
    end

    def refresh
      refreshing do
        refresh_datasource
        process_data
      end
    end

    def needs_refresh?
      return true if refreshed_at.nil?
      return true if columns.where("updated_at > ?", refreshed_at).exists?
      return true if transforms.where("updated_at > ?", refreshed_at).exists?
      return true if datasource&.needs_refresh?

      false
    end

    def refreshing
      return false if locked?

      update(workflow_status: "analyzing")
      fully_reload
      yield
      learn_schema
      learn_statistics
      sync_columns
      now = UTC.now
      update(workflow_status: "ready", refreshed_at: now, updated_at: now)
      fully_reload
    rescue StandardError => e
      update(workflow_status: "failed")
      raise e
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
        statistics: EasyML::Data::StatisticsLearner.learn(raw, processed)
      )
    end

    def syncable_cols
      col_names = schema.keys

      return col_names unless preprocessing_steps.present?

      col_names - one_hot_cols
    end

    def one_hot_cols
      one_hot_base_cols = preprocessing_steps[:training].select { |_k, v| v.dig(:params, :one_hot) }.keys.map(&:to_s)
      return [] unless one_hot_base_cols

      col_names = schema.keys

      allowed_values = one_hot_base_cols.inject({}) do |h, col|
        col = col.to_s
        h.tap do
          h[col] = raw.read(:train, select: col)[col].unique.to_a + ["other"]
        end
      end
      col_names.select do |col|
        col = col.to_s
        one_hot_base_cols.any? do |base|
          if !col.start_with?("#{base}_")
            false
          else
            allowed_vals = allowed_values[base].compact
            allowed_vals.any? do |val|
              col.end_with?(val)
            end
          end
        end
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
            dataset_id: id
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

          column.assign_attributes(
            statistics: {
              raw: stats.dig("raw", column.name),
              processed: stats.dig("processed", column.name)
            },
            datatype: actual_schema_type,
            polars_datatype: actual_type,
            sample_values: data(unique: true, limit: 5, select: column.name,
                                all_columns: true)[column.name].to_a.uniq[0...5]
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

    def normalize(df = nil, split_ys: false, inference: false)
      df = drop_nulls(df)
      df = apply_transforms(df)
      df = preprocessor.postprocess(df, inference: inference)
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
    def train(**kwargs)
      load_data(:train, **kwargs)
    end

    def valid(**kwargs)
      load_data(:valid, **kwargs)
    end

    def test(**kwargs)
      load_data(:test, **kwargs)
    end

    def data(**kwargs)
      load_data(:all, **kwargs)
    end

    def num_batches(segment)
      processed.num_batches(segment)
    end

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
        inference: inference
      }.compact.deep_symbolize_keys
    end

    def preprocessor
      @preprocessor ||= initialize_preprocessor
      return @preprocessor if @preprocessor.preprocessing_steps == preprocessing_steps

      @preprocessor = initialize_preprocessor
    end

    def target
      @target ||= columns.find_by(is_target: true)&.name
    end

    def drop_cols
      @drop_cols ||= columns.select(&:hidden).map(&:name)
    end

    def drop_if_null
      @drop_if_null ||= columns.where(drop_if_null: true).map(&:name)
    end

    def drop_columns(all_columns: false)
      if all_columns
        []
      else
        drop_cols
      end
    end

    def files
      [raw, processed, locked].flat_map(&:files)
    end

    def load_dataset
      download_remote_files
    end

    private

    def download_remote_files
      return unless is_history_class? # Only historical datasets need this
      return if processed.present? && processed.data

      processed.download
    end

    def upload_remote_files
      return unless processed?

      processed.upload
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
          dir: Pathname.new(root_dir).append("files/splits/#{type}").to_s
        ))
      end
    end

    def split_type
      datasource.in_memory? ? EasyML::Data::Splits::InMemorySplit : EasyML::Data::Splits::FileSplit
    end

    def refresh_datasource
      datasource.reload.refresh
      initialize_splits
    end

    # log_method :refresh_datasource, "Refreshing datasource", verbose: true

    def refresh_datasource!
      datasource.reload.refresh!
      initialize_splits
    end

    # log_method :refresh_datasource!, "Refreshing! datasource", verbose: true

    def normalize_all
      processed.cleanup

      SPLIT_ORDER.each do |segment|
        df = raw.read(segment)
        processed_df = normalize(df)
        processed.save(segment, processed_df)
      end
      @normalized = true
    end

    # log_method :normalize_all, "Normalizing dataset", verbose: true

    def drop_nulls(df)
      return df if drop_if_null.nil? || drop_if_null.empty?

      drop = (df.columns & drop_if_null)
      return df if drop.empty?

      df.drop_nulls(subset: drop)
    end

    def load_data(segment, **kwargs)
      if processed?
        processed.load_data(segment, **kwargs)
      else
        raw.load_data(segment, **kwargs)
      end
    end

    def fit(xs = nil)
      xs = raw.train(all_columns: true) if xs.nil?

      preprocessor.fit(xs)
      self.preprocessor_statistics = preprocessor.statistics
    end

    # log_method :fit, "Learning statistics", verbose: true

    def in_batches(segment, processed: true, &block)
      if processed
        processed.read(segment, &block)
      else
        raw.read(segment, &block)
      end
    end

    def split_data!
      split_data(force: true)
    end

    def split_data(force: false)
      return unless force || should_split?

      cleanup
      transforms = self.transforms.ordered.load
      datasource.in_batches do |df|
        df = apply_transforms(df, transforms) if transforms.any?
        train_df, valid_df, test_df = splitter.split(df)
        raw.save(:train, train_df)
        raw.save(:valid, valid_df)
        raw.save(:test, test_df)
      end
    end

    # log_method :split_data, "Splitting data", verbose: true

    def should_split?
      split_timestamp = raw.split_at
      processed.split_at.nil? || split_timestamp.nil? || split_timestamp < datasource.last_updated_at
    end

    def apply_transforms(df, transforms = self.transforms)
      if transforms.nil? || transforms.empty?
        df
      else
        transforms.ordered.reduce(df) do |acc_df, transform|
          result = transform.apply!(acc_df)

          unless result.is_a?(Polars::DataFrame)
            raise "Transform '#{transform.transform_method}' must return a Polars::DataFrame, got #{result.class}"
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
        preprocessing_steps: preprocessing_steps
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
          new: polars_type
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
