require "polars"
require_relative "dataset/splitters"
require_relative "dataset/splits"

# Dataset is responsible for:
#
# 1) Ensuring data is synced from its source (e.g. S3 — delegates to datasource)
# 2) Ensuring the data is properly split into train, test, and validation data (delegates to splitter)
# 3) Knowing where data is stored on disk, and pulling batches of data into memory
# 4) Knowing where to save updated data (after preprocessing steps)
#
module EasyML
  module Data
    class Dataset
      include GlueGun::DSL
      include EasyML::Logging
      include EasyML::Data::Utils

      # include GitIgnorable
      # gitignore :root_dir do |dir|
      #   if Rails.env.test? # Don't gitignore our test files
      #     nil
      #   else
      #     File.join(dir, "files/**/*")
      #   end
      # end

      # These helpers are defined in GlueGun::DSL.
      #
      # define_attr defines configurable attributes for subclasses,
      # for example, a class sub-classing Dataset will want to define its
      # target (e.g. the column we are trying to predict)
      #
      # These can either be defined on a class-level like this:
      #
      # class Dataset < EasyML::Data::Dataset
      #   target "REVENUE"
      # end
      #
      # Or passed in during initialization:
      #
      # Dataset.new(target: "REV")
      #
      attribute :verbose, :boolean, default: false
      attribute :today, :date
      def today=(value)
        value ||= UTC.now
        super(value.in_time_zone(UTC).to_date)
      end

      attribute :batch_size, :integer, default: 50_000

      attribute :root_dir, :string
      validates :root_dir, presence: true
      def root_dir=(value)
        super(Pathname.new(value).append("data").to_s)
      end

      # define_attr can also define default values, as well as argument helpers
      attribute :polars_args, :hash, default: {}
      def polars_args=(args)
        super(args.deep_symbolize_keys.inject({}) do |hash, (k, v)|
          hash.tap do
            hash[k] = v
            hash[k] = v.stringify_keys if k == :dtypes
          end
        end)
      end

      attribute :transforms, default: nil
      validate :transforms_are_transforms
      def transforms_are_transforms
        return if transforms.nil? || transforms.respond_to?(:transform)

        errors.add(:transforms, "Must respond to transform, try including EasyML::Data::Transforms")
      end

      attribute :datasource
      attribute :columns
      attribute :schema
      attribute :statistics

      # dependency defines a configurable dependency, with optional args,
      # for example, here we define a datasource:
      #
      # class YourDataset
      #   datasource :s3, s3_bucket: "fundera-bart", s3_prefix: "xyz"
      #   # This automatically uses the S3Datasource class to pull data
      # end
      #
      # If we define any models based on other data sources (e.g. postgres),
      # you would just define a new PostgresDatasource
      #

      # Here we define splitter options, inspired by common Python data splitting techniques:
      #
      # 1. Date-based splitter (similar to TimeSeriesSplit from sklearn)
      #
      # NOT IMPLEMENTED (but you could implement as necessary):
      # 2. Random splitter (similar to train_test_split from sklearn)
      # 3. Stratified splitter (similar to StratifiedKFold from sklearn)
      # 4. Group-based splitter (similar to GroupKFold from sklearn)
      # 5. Sliding window splitter (similar to TimeSeriesSplit with a sliding window)
      #
      dependency :splitter do |dependency|
        dependency.option :date do |option|
          option.default
          option.set_class EasyML::Data::Dataset::Splitters::DateSplitter
          option.bind_attribute :today, required: true
          option.bind_attribute :date_col, required: true
          option.bind_attribute :months_test, required: true
          option.bind_attribute :months_valid, required: true
        end
      end

      # Here we define the raw dataset (uses the Split class)
      # We use this to learn dataset statistics (e.g. median annual revenue)
      # But we NEVER overwrite it
      #
      dependency :raw do |dependency|
        dependency.option :file do |option|
          option.default
          option.set_class EasyML::Data::Dataset::Splits::FileSplit
          option.bind_attribute :dir, source: :root_dir do |value|
            Pathname.new(value).append("files/splits/raw")
          end
          option.bind_attribute :polars_args
          option.bind_attribute :max_rows_per_file, source: :batch_size
          option.bind_attribute :batch_size
          option.bind_attribute :verbose
        end

        dependency.option :memory do |option|
          option.set_class EasyML::Data::Dataset::Splits::InMemorySplit
        end

        dependency.when do |_dep|
          { option: :memory } if datasource.respond_to?(:df)
        end
      end

      # Here we define the processed dataset (uses the Split class)
      # After we learn the dataset statistics, we fill null values
      # using the learned statistics (e.g. fill annual_revenue with median annual_revenue)
      #
      dependency :processed do |dependency|
        dependency.option :file do |option|
          option.default
          option.set_class EasyML::Data::Dataset::Splits::FileSplit
          option.bind_attribute :dir, source: :root_dir do |value|
            Pathname.new(value).append("files/splits/processed")
          end
          option.bind_attribute :polars_args
          option.bind_attribute :max_rows_per_file, source: :batch_size
          option.bind_attribute :batch_size
          option.bind_attribute :verbose
        end

        dependency.option :memory do |option|
          option.set_class EasyML::Data::Dataset::Splits::InMemorySplit
        end

        dependency.when do |_dep|
          { option: :memory } if datasource.respond_to?(:df)
        end
      end

      delegate :new_data_available?, :synced?, :stale?, to: :datasource
      delegate :train, :test, :valid, to: :split
      delegate :splits, to: :splitter

      SPLIT_ORDER = %i[train valid test]

      def process_data
        split_data
        fit
        normalize_all
        alert_nulls
      end

      def refresh
        refresh_datasource
        process_data
      end

      def refresh!
        cleanup
        refresh_datasource!
        process_data
      end

      def normalize(df = nil, split_ys: false)
        df = drop_nulls(df)
        # df = apply_transforms(df)
        df = preprocessor.postprocess(df)
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
              if df_nulls && df_nulls[column]
                segment_result[:nulls][column][:null_count] += df_nulls[column][:null_count]
              end
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

      def initialize_preprocessor
        EasyML::Data::Preprocessor.new(
          directory: Pathname.new(root_dir).append("preprocessor"),
          preprocessing_steps: preprocessing_steps
        )
      end

      def target
        @target ||= columns.find_by(is_target: true)&.name
      end

      def drop_cols
        @drop_cols ||= columns.select(&:hidden).map(&:name)
      end

      def drop_if_null
        @drop_if_null ||= columns.select(&:drop_if_null).map(&:name)
      end

      private

      def refresh_datasource
        datasource.refresh
      end
      # log_method :refresh_datasource, "Refreshing datasource", verbose: true

      def refresh_datasource!
        datasource.refresh!
      end
      log_method :refresh_datasource!, "Refreshing! datasource", verbose: true

      def normalize_all
        processed.cleanup

        SPLIT_ORDER.each do |segment|
          df = raw.read(segment)
          processed_df = normalize(df)
          processed.save(segment, processed_df)
        end
      end
      log_method :normalize_all, "Normalizing dataset", verbose: true

      def drop_nulls(df)
        return df if drop_if_null.nil? || drop_if_null.empty?

        drop = (df.columns & drop_if_null)
        return df if drop.empty?

        df.drop_nulls(subset: drop)
      end

      def drop_columns(all_columns: false)
        if all_columns
          []
        else
          drop_cols
        end
      end

      def load_data(segment, **kwargs)
        drop_cols = drop_columns(all_columns: kwargs[:all_columns] || false)
        kwargs.delete(:all_columns)
        kwargs = kwargs.merge!(drop_cols: drop_cols, target: target)
        if processed?
          processed.read(segment, **kwargs)
        else
          raw.read(segment, **kwargs)
        end
      end

      def fit(xs = nil)
        xs = raw.train if xs.nil?

        preprocessor.fit(xs)
      end
      log_method :fit, "Learning statistics", verbose: true

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
        puts "Should split? #{force || should_split?}"
        return unless force || should_split?

        cleanup
        datasource.in_batches do |df|
          df = apply_transforms(df)
          train_df, valid_df, test_df = splitter.split(df)
          raw.save(:train, train_df)
          raw.save(:valid, valid_df)
          raw.save(:test, test_df)
        end
      end
      log_method :split_data, "Splitting data", verbose: true

      def should_split?
        split_timestamp = raw.split_at
        processed.split_at.nil? || split_timestamp.nil? || split_timestamp < datasource.last_updated_at
      end

      def apply_transforms(df)
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

      def alert_nulls
        processed_nulls = check_nulls(:processed)
        raw_nulls = check_nulls(:raw)

        if processed_nulls
          log_warning("Nulls found in the processed dataset:")
          processed_nulls.each do |column, segments|
            segments.each do |segment, percentage|
              log_warning("  #{column} - #{segment}: #{percentage}% nulls")
            end
          end
        else
          log_info("No nulls found in the processed dataset.")
        end

        if raw_nulls
          raw_nulls.each do |column, segments|
            segments.each do |segment, percentage|
              if percentage > 50
                log_warning("Data processing issue detected: #{column} - #{segment} has #{percentage}% nulls in the raw dataset")
              end
            end
          end
        end

        nil
      end
      log_method :alert_nulls, "Checking for nulls", verbose: true
    end
  end
end
