require "polars"
require_relative "datasource"
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
      attribute :today, :date, default: -> { UTC.now }
      def today=(value)
        super(value.in_time_zone(UTC).to_date)
      end
      attribute :target, :string
      validates :target, presence: true

      attribute :batch_size, :integer, default: 50_000

      attribute :root_dir, :string
      validates :root_dir, presence: true
      def root_dir=(value)
        super(Pathname.new(value).append("data").to_s)
      end

      attribute :sample, :float, default: 1.0
      attribute :drop_if_null, :array, default: []

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

      attribute :drop_cols, :array, default: []

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
      dependency :datasource do |dependency|
        dependency.option :s3 do |option|
          option.default
          option.set_class EasyML::Data::Datasource::S3Datasource
          option.bind_attribute :root_dir do |value|
            Pathname.new(value).append("files")
          end
          option.bind_attribute :polars_args, default: {}
          option.bind_attribute :s3_bucket, required: true
          option.bind_attribute :s3_prefix
          option.bind_attribute :s3_access_key_id, required: true
          option.bind_attribute :s3_secret_access_key, required: true
        end

        dependency.option :file do |option|
          option.set_class EasyML::Data::Datasource::FileDatasource
          option.bind_attribute :root_dir do |value|
            Pathname.new(value).append("files/raw")
          end
          option.bind_attribute :polars_args
        end

        dependency.option :polars do |option|
          option.set_class EasyML::Data::Datasource::PolarsDatasource
          option.bind_attribute :df
        end

        # Passing in datasource: Polars::DataFrame will wrap properly
        # So will passing in datasource /path/to/dir
        dependency.when do |dep|
          case dep
          when Polars::DataFrame
            { option: :polars, as: :df }
          when String, Pathname
            { option: :file, as: :root_dir }
          end
        end
      end

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

      # Here we define the preprocessing logic.
      # Aka what to do with null values. For instance:
      #
      # class YourDataset
      #   preprocessing_steps: {
      #     training: {
      #       annual_revenue: {
      #         clip: {min: 0, max: 1_000_000} # Clip values between these
      #         median: true, # Then learn the median based on clipped values
      #       },
      #       created_date: { ffill: true } # During training, use the latest value in the dataset
      #     },
      #     inference: {
      #       created_date: { today: true } # During inference, use the current date
      #     }
      #   }
      # end
      #
      attribute :preprocessing_steps, :hash, default: {}
      dependency :preprocessor do |dependency|
        dependency.set_class EasyML::Data::Preprocessor
        dependency.bind_attribute :directory, source: :root_dir do |value|
          Pathname.new(value).append("preprocessor")
        end
        dependency.bind_attribute :preprocessing_steps
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
          option.bind_attribute :sample
          option.bind_attribute :verbose
        end

        dependency.option :memory do |option|
          option.set_class EasyML::Data::Dataset::Splits::InMemorySplit
          option.bind_attribute :sample
        end

        dependency.when do |_dep|
          { option: :memory } if datasource.is_a?(EasyML::Data::Datasource::PolarsDatasource)
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
          option.bind_attribute :sample
          option.bind_attribute :verbose
        end

        dependency.option :memory do |option|
          option.set_class EasyML::Data::Dataset::Splits::InMemorySplit
          option.bind_attribute :sample
        end

        dependency.when do |_dep|
          { option: :memory } if datasource.is_a?(EasyML::Data::Datasource::PolarsDatasource)
        end
      end

      delegate :new_data_available?, :synced?, :stale?, to: :datasource
      delegate :train, :test, :valid, to: :split
      delegate :splits, to: :splitter

      def refresh!
        refresh_datasource
        split_data
        fit
        normalize_all
        alert_nulls
      end

      def normalize(df = nil)
        df = drop_nulls(df)
        df = apply_transforms(df)
        preprocessor.postprocess(df)
      end

      # A "production" preprocessor is predicting live values (e.g. used on live webservers)
      # A "development" preprocessor is used during training (e.g. we're learning new values for the dataset)
      #
      delegate :statistics, to: :preprocessor

      def train(split_ys: false, all_columns: false, &block)
        load_data(:train, split_ys: split_ys, all_columns: all_columns, &block)
      end

      def valid(split_ys: false, all_columns: false, &block)
        load_data(:valid, split_ys: split_ys, all_columns: all_columns, &block)
      end

      def test(split_ys: false, all_columns: false, &block)
        load_data(:test, split_ys: split_ys, all_columns: all_columns, &block)
      end

      def data(split_ys: false, all_columns: false)
        if split_ys
          x_train, y_train = train(split_ys: true, all_columns: all_columns)
          x_valid, y_valid = valid(split_ys: true, all_columns: all_columns)
          x_test, y_test = test(split_ys: true, all_columns: all_columns)

          xs = Polars.concat([x_train, x_valid, x_test])
          ys = Polars.concat([y_train, y_valid, y_test])
          [xs, ys]
        else
          train_df = train(split_ys: false, all_columns: all_columns)
          valid_df = valid(split_ys: false, all_columns: all_columns)
          test_df = test(split_ys: false, all_columns: all_columns)

          Polars.concat([train_df, valid_df, test_df])
        end
      end

      def cleanup
        raw.cleanup
        processed.cleanup
      end

      def check_nulls(data_type = :processed)
        result = %i[train test valid].each_with_object({}) do |segment, acc|
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

      private

      def refresh_datasource
        datasource.refresh!
      end
      log_method :refresh!, "Refreshing datasource", verbose: true

      def normalize_all
        processed.cleanup

        %i[train test valid].each do |segment|
          raw.read(segment) do |df|
            processed_df = normalize(df)
            processed.save(segment, processed_df)
          end
        end
      end
      log_method :normalize_all, "Normalizing dataset", verbose: true

      def drop_nulls(df)
        return df if drop_if_null.nil? || drop_if_null.empty?

        df.drop_nulls(subset: drop_if_null)
      end

      def drop_columns(all_columns: false)
        if all_columns
          []
        else
          drop_cols
        end
      end

      def load_data(segment, split_ys: false, all_columns: false, &block)
        drop_cols = drop_columns(all_columns: all_columns)
        if processed?
          processed.read(segment, split_ys: split_ys, target: target, drop_cols: drop_cols, &block)
        else
          raw.read(segment, split_ys: split_ys, target: target, drop_cols: drop_cols, &block)
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

      def split_data
        return unless should_split?

        cleanup
        datasource.in_batches do |df|
          train_df, valid_df, test_df = splitter.split(df)
          raw.save(:train, train_df)
          raw.save(:valid, valid_df)
          raw.save(:test, test_df)
        end

        # Update the persisted sample size after splitting
        save_previous_sample(sample)
      end
      log_method :split_data, "Splitting data", verbose: true

      def should_split?
        split_timestamp = raw.split_at
        previous_sample = load_previous_sample
        sample_increased = previous_sample && sample > previous_sample
        previous_sample.nil? || split_timestamp.nil? || split_timestamp < datasource.last_updated_at || sample_increased
      end

      def sample_info_file
        File.join(root_dir, "sample_info.json")
      end

      def save_previous_sample(sample_size)
        File.write(sample_info_file, JSON.generate({ previous_sample: sample_size }))
      end

      def load_previous_sample
        return nil unless File.exist?(sample_info_file)

        JSON.parse(File.read(sample_info_file))["previous_sample"]
      end

      def apply_transforms(df)
        if transforms.nil?
          df
        else
          transforms.apply_transforms(df)
        end
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
