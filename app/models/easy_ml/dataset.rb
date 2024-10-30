# == Schema Information
#
# Table name: easy_ml_datasets
#
#  id                  :bigint           not null, primary key
#  name                :string           not null
#  status              :string
#  version             :string
#  datasource_id       :bigint
#  root_dir            :string
#  configuration       :json
#  verbose             :boolean          default(FALSE)
#  today               :date
#  target              :string           not null
#  batch_size          :integer          default(50000)
#  drop_if_null        :string           default([]), not null, is an Array
#  polars_args         :json
#  drop_cols           :string           default([]), not null, is an Array
#  preprocessing_steps :json
#  splitter            :json
#  transforms          :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
require_relative "concerns/statuses"
require_relative "concerns/configurable_adapter"
module EasyML
  class Dataset < ActiveRecord::Base
    include EasyML::Concerns::Statuses
    include EasyML::Logging
    include EasyML::Data::Utils
    include EasyML::Concerns::ConfigurableAdapter

    self.filter_attributes += [:configuration]

    validates :name, :target, presence: true

    belongs_to :datasource,
               foreign_key: :datasource_id,
               class_name: "EasyML::Datasource"

    has_many :models, class_name: "EasyML::Model"

    after_initialize :set_defaults

    delegate :new_data_available?, :synced?, :stale?, to: :datasource
    delegate :splits, to: :splitter
    delegate :statistics, to: :preprocessor

    configurable_adapter :splitter,
                         options: {
                           date: EasyML::Data::Dataset::Splitters::DateSplitter
                         }

    def root_dir=(value)
      raise "root_dir required" if value.nil?

      super(Pathname.new(value).append("data").to_s)
    end

    def today=(value)
      value ||= UTC.now
      super(value.in_time_zone(UTC).to_date)
    end

    def process_data
      split_data
      fit
      normalize_all
      alert_nulls
    end

    def refresh
      refresh_datasource
      return if processed?

      process_data
    end

    def refresh!
      cleanup
      refresh_datasource!
      process_data
    end

    def normalize(df = nil, split_ys: false)
      df = drop_nulls(df)
      df = apply_transforms(df)
      df = preprocessor.postprocess(df)
      df, = processed.split_features_targets(df, true, target) if split_ys
      df
    end

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
      result = %i[train test valid].each_with_object({}) do |segment, acc|
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

    def polars_args
      polars_args = read_attribute(:polars_args) || {}
      polars_args.deep_symbolize_keys.inject({}) do |hash, (k, v)|
        hash.tap do
          hash[k] = v
          hash[k] = v.stringify_keys if k == :dtypes
        end
      end
    end

    def raw
      @raw ||= build_split("raw")
    end

    def processed
      @processed ||= build_split("processed")
    end

    def preprocessor
      @preprocessor ||= EasyML::Data::Preprocessor.new(
        directory: Pathname.new(root_dir).append("preprocessor"),
        preprocessing_steps: preprocessing_steps
      )
    end

    private

    def set_defaults
      self.polars_args ||= {}
      self.drop_if_null ||= []
      self.drop_cols ||= []
      self.preprocessing_steps ||= {}
      self.batch_size ||= 50_000
      self.verbose ||= false
    end

    def refresh_datasource
      datasource.refresh
    end
    log_method :refresh, "Refreshing datasource", verbose: true

    def refresh_datasource!
      datasource.refresh!
    end
    log_method :refresh!, "Refreshing! datasource", verbose: true

    def normalize_all
      processed.cleanup

      %i[train test valid].each do |segment|
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

    def build_split(split_type)
      if datasource.respond_to?(:df)
        EasyML::Data::Dataset::Splits::InMemorySplit.new(
          polars_args: polars_args,
          verbose: verbose
        )
      else
        raise "root_dir required" unless root_dir.present?

        EasyML::Data::Dataset::Splits::FileSplit.new(
          dir: Pathname.new(root_dir).append("files/splits/#{split_type}"),
          polars_args: polars_args,
          max_rows_per_file: batch_size,
          batch_size: batch_size,
          verbose: verbose
        )
      end
    end
  end
end
