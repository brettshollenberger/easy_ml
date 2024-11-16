require "fileutils"
require "polars"
require "date"
require "json"
require_relative "simple_imputer"

module EasyML::Data
  class Preprocessor
    include GlueGun::DSL

    CATEGORICAL_COMMON_MIN = 50

    ALLOWED_PARAMS = {
      constant: [:constant],
      categorical: %i[categorical_min one_hot ordinal_encoding],
      most_frequent: %i[one_hot ordinal_encoding],
      mean: [:clip],
      median: [:clip]
    }

    PREPROCESSING_STRATEGIES = {
      float: [
        { value: "mean", label: "Mean" },
        { value: "median", label: "Median" },
        { value: "constant", label: "Constant Value" }
      ],
      integer: [
        { value: "mean", label: "Mean" },
        { value: "median", label: "Median" },
        { value: "constant", label: "Constant Value" }
      ],
      boolean: [
        { value: "most_frequent", label: "Most Frequent" },
        { value: "constant", label: "Constant Value" }
      ],
      datetime: [
        { value: "ffill", label: "Forward Fill" },
        { value: "constant", label: "Constant Value" },
        { value: "today", label: "Current Date" }
      ],
      string: [
        { value: "most_frequent", label: "Most Frequent" },
        { value: "constant", label: "Constant Value" }
      ],
      text: [
        { value: "most_frequent", label: "Most Frequent" },
        { value: "constant", label: "Constant Value" }
      ],
      categorical: [
        { value: "categorical", label: "Categorical" },
        { value: "most_frequent", label: "Most Frequent" },
        { value: "constant", label: "Constant Value" }
      ]
    }.freeze

    attribute :directory
    attribute :verbose
    attribute :imputers
    attribute :preprocessing_steps

    attr_reader :statistics

    def statistics=(stats)
      @statistics = (stats || {}).deep_symbolize_keys
    end

    def apply_clip(df, preprocessing_steps)
      df = df.clone
      preprocessing_steps ||= {}
      preprocessing_steps.deep_symbolize_keys!

      (preprocessing_steps[:training] || {}).each_key do |col|
        clip_params = preprocessing_steps.dig(:training, col, :params, :clip)
        next unless clip_params

        min = clip_params[:min]
        max = clip_params[:max]
        df[col.to_s] = df[col.to_s].clip(min, max)
      end

      df
    end

    def learn_categorical_min(df, preprocessing_steps)
      preprocessing_steps ||= {}
      preprocessing_steps.deep_symbolize_keys!

      allowed_categories = {}
      (preprocessing_steps[:training] || {}).each_key do |col|
        next unless preprocessing_steps.dig(:training, col, :method).to_s == "categorical"

        cat_min = preprocessing_steps.dig(:training, col, :params, :categorical_min) || 0
        val_counts = df[col].value_counts
        allowed_categories[col] = val_counts[val_counts["count"] >= cat_min][col].to_a
      end
      allowed_categories
    end

    def fit(df)
      return if df.nil?
      return if preprocessing_steps.nil? || preprocessing_steps.keys.none?

      preprocessing_steps.deep_symbolize_keys!
      df = apply_clip(df, preprocessing_steps)
      allowed_categories = learn_categorical_min(df, preprocessing_steps)

      self.statistics = StatisticsLearner.learn_df(df).deep_symbolize_keys

      # Merge allowed categories into statistics
      allowed_categories.each do |col, categories|
        statistics[col] ||= {}
        statistics[col][:allowed_categories] = categories
        statistics[col].merge!(
          fit_categorical(df[col], preprocessing_steps)
        )
      end
    end

    def postprocess(df, inference: false)
      puts "Postprocessing..." if verbose
      return df if preprocessing_steps.nil? || preprocessing_steps.keys.none?

      steps = if inference
                preprocessing_steps[:training].merge(preprocessing_steps[:inference] || {})
              else
                preprocessing_steps[:training]
              end

      df = apply_transformations(df, steps)

      puts "Postprocessing complete." if @verbose
      df
    end

    def decode_labels(values, col: nil)
      imputers = initialize_imputers(preprocessing_steps[:training])
      imputer = imputers.dig(col.to_sym, :categorical)
      decoder = imputer.statistics.dig(:categorical, :label_decoder)
      other_value = decoder.keys.map(&:to_s).map(&:to_i).max + 1
      decoder[other_value] = "other"
      decoder.stringify_keys!

      values.map do |value|
        decoder[value.to_s]
      end
    end

    def is_fit?
      statistics.any? { |_, col_stats| col_stats.any? { |_, strategy_stats| strategy_stats.present? } }
    end

    def delete
      return unless File.directory?(@directory)

      FileUtils.rm_rf(@directory)
    end

    def serialize
      attributes.merge!(
        statistics: serialize_statistics(statistics || {})
      )
    end

    private

    def initialize_imputers(config)
      config.each_with_object({}) do |(col, conf), hash|
        hash[col] ||= {}
        conf.symbolize_keys!
        method = conf[:method]
        params = conf[:params] || {}

        hash[col][method] = EasyML::Data::SimpleImputer.new(
          strategy: method,
          options: params,
          path: directory,
          attribute: col,
          statistics: statistics.dig(col)
        )
      end
    end

    def apply_transformations(df, config)
      imputers = initialize_imputers(config)

      df = apply_clip(df, { training: config })

      config.each do |col, conf|
        conf.symbolize_keys!
        if df.columns.map(&:downcase).map(&:to_s).include?(col.downcase.to_s)
          actual_col = df.columns.map(&:to_s).find { |c| c.to_s.downcase == col.to_s.downcase }

          strategy = conf[:method]
          params = conf[:params]
          imputer = imputers.dig(col, strategy)

          df[actual_col] = imputer.transform(df[actual_col]) if imputer

          if params.is_a?(Hash) && params.key?(:one_hot) && params[:one_hot] == true
            df = apply_one_hot(df, col)
          elsif params.is_a?(Hash) && params.key?(:ordinal_encoding) && params[:ordinal_encoding] == true
            df = apply_ordinal_encoding(df, col)
          end
        elsif @verbose
          puts "Warning: Column '#{col}' not found in DataFrame during apply_transformations process."
        end
      end

      df
    end

    def apply_one_hot(df, col)
      dtype = df[col].dtype
      approved_values = statistics.dig(col, :allowed_categories)

      # Create one-hot encoded columns
      approved_values.each do |value|
        new_col_name = "#{col}_#{value}".gsub(/-/, "_")
        df = df.with_column(
          df[col].eq(value.to_s).cast(dtype).alias(new_col_name)
        )
      end

      # Create 'other' column for unapproved values
      other_col_name = "#{col}_other"
      df[other_col_name] = df[col].map_elements do |value|
        approved_values.map(&:to_s).exclude?(value)
      end.cast(dtype)
      df.drop([col.to_s])
    end

    def apply_ordinal_encoding(df, col)
      approved_values = statistics.dig(col, :allowed_categories)

      df.with_column(
        df[col].map_elements do |value|
          approved_values.map(&:to_s).exclude?(value) ? "other" : value
        end.alias(col.to_s)
      )

      label_encoder = statistics.dig(col, :label_encoder).stringify_keys
      other_value = label_encoder.values.max + 1
      label_encoder["other"] = other_value
      df.with_column(
        df[col].map { |v| label_encoder[v.to_s] }.alias(col.to_s)
      )
    end

    def fit_categorical(series, _preprocessing_steps)
      value_counts = series.value_counts
      column_names = value_counts.columns
      value_column = column_names[0]
      count_column = column_names[1]

      as_hash = value_counts.select([value_column, count_column]).rows.to_a.to_h.transform_keys(&:to_s)
      label_encoder = as_hash.keys.sort.each.with_index.reduce({}) do |h, (k, i)|
        h.tap do
          h[k] = i
        end
      end
      label_decoder = label_encoder.invert

      {
        value: as_hash,
        label_encoder: label_encoder,
        label_decoder: label_decoder
      }
    end

    def prepare_for_imputation(df, col)
      df = df.with_column(Polars.col(col).cast(Polars::Float64))
      df.with_column(Polars.when(Polars.col(col).is_null).then(Float::NAN).otherwise(Polars.col(col)).alias(col))
    end

    def serialize_statistics(stats)
      stats.deep_transform_values do |value|
        case value
        when Time, DateTime
          { "__type__" => "datetime", "value" => value.iso8601 }
        when Date
          { "__type__" => "date", "value" => value.iso8601 }
        when BigDecimal
          { "__type__" => "bigdecimal", "value" => value.to_s }
        when Polars::DataType
          { "__type__" => "polars_dtype", "value" => value.to_s }
        when Symbol
          { "__type__" => "symbol", "value" => value.to_s }
        else
          value
        end
      end
    end

    def deserialize_statistics(stats)
      return nil if stats.nil?

      stats.transform_values do |value|
        recursive_deserialize(value)
      end
    end

    def recursive_deserialize(value)
      case value
      when Hash
        if value["__type__"]
          deserialize_special_type(value)
        else
          value.transform_values { |v| recursive_deserialize(v) }
        end
      when Array
        value.map { |v| recursive_deserialize(v) }
      else
        value
      end
    end

    def deserialize_special_type(value)
      case value["__type__"]
      when "datetime"
        DateTime.parse(value["value"])
      when "date"
        Date.parse(value["value"])
      when "bigdecimal"
        BigDecimal(value["value"])
      when "polars_dtype"
        parse_polars_dtype(value["value"])
      when "symbol"
        value["value"].to_sym
      else
        value["value"]
      end
    end

    def parse_polars_dtype(dtype_string)
      case dtype_string
      when /^Polars::Datetime/
        time_unit = dtype_string[/time_unit: "(.*?)"/, 1]
        time_zone = dtype_string[/time_zone: (.*)?\)/, 1]
        time_zone = time_zone == "nil" ? nil : time_zone&.delete('"')
        Polars::Datetime.new(time_unit: time_unit, time_zone: time_zone).class
      when /^Polars::/
        Polars.const_get(dtype_string.split("::").last)
      else
        raise ArgumentError, "Unknown Polars data type: #{dtype_string}"
      end
    end

    def cast_to_dtype(value, dtype)
      case dtype
      when Polars::Int64
        value.to_i
      when Polars::Float64
        value.to_f
      when Polars::Boolean
        !!value
      when Polars::Utf8
        value.to_s
      else
        value
      end
    end

    def self.constants
      {
        preprocessing_strategies: PREPROCESSING_STRATEGIES
      }
    end
  end
end
