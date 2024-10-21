require "fileutils"
require "polars"
require "date"
require "json"
require_relative "simple_imputer"

module EasyML::Data
  class Preprocessor
    include GlueGun::DSL

    CATEGORICAL_COMMON_MIN = 50
    PREPROCESSING_ORDER = %w[clip mean median constant categorical one_hot ffill custom fill_date add_datepart]

    attribute :directory
    attribute :verbose
    attribute :imputers
    attribute :preprocessing_steps
    attr_reader :statistics

    def statistics=(stats)
      @statistics = stats.deep_symbolize_keys
    end

    def statistics
      serialize_statistics(@statistics || {})
    end

    def fit(df)
      return if df.nil?
      return if preprocessing_steps.nil? || preprocessing_steps.keys.none?

      preprocessing_steps.deep_symbolize_keys!

      puts "Preprocessing..." if verbose
      imputers = initialize_imputers(
        preprocessing_steps[:training].merge!(preprocessing_steps[:inference] || {})
      )

      stats = {}
      imputers.each do |col, imputers|
        sorted_strategies(imputers).each do |strategy|
          imputer = imputers[strategy]
          if df.columns.map(&:downcase).map(&:to_s).include?(col.downcase.to_s)
            actual_col = df.columns.map(&:to_s).find { |c| c.to_s.downcase == imputer.attribute.downcase.to_s }
            stats.deep_merge!(
              imputer.fit(df[actual_col], df)
            )
            if strategy == "clip" # This is the only one to transform during fit
              df[actual_col] = imputer.transform(df[actual_col])
            end
          elsif @verbose
            puts "Warning: Column '#{col}' not found in DataFrame during fit process."
          end
        end
      end
      self.statistics = stats
    end

    def postprocess(df, inference: false)
      puts "Postprocessing..." if verbose
      return df if preprocessing_steps.keys.none?

      steps = if inference
                preprocessing_steps[:training].merge(preprocessing_steps[:inference] || {})
              else
                preprocessing_steps[:training]
              end

      df = apply_transformations(df, steps)

      puts "Postprocessing complete." if @verbose
      df
    end

    def is_fit?
      statistics.any? { |_, col_stats| col_stats.any? { |_, strategy_stats| strategy_stats.present? } }
    end

    def delete
      return unless File.directory?(@directory)

      FileUtils.rm_rf(@directory)
    end

    private

    def standardize_config(config)
      config.each do |column, strategies|
        next unless strategies.is_a?(Array)

        config[column] = strategies.reduce({}) do |hash, strategy|
          hash.tap do
            hash[strategy] = true
          end
        end
      end
    end

    def initialize_imputers(config)
      standardize_config(config).each_with_object({}) do |(col, strategies), hash|
        hash[col] ||= {}
        strategies.each do |strategy, options|
          next if strategy.to_sym == :one_hot

          options = {} if options == true

          imputer_stats = deserialize_statistics((statistics || {}).deep_stringify_keys.dig(col.to_s))
          hash[col][strategy] = EasyML::Data::SimpleImputer.new(
            strategy: strategy,
            path: directory,
            attribute: col,
            options: options,
            statistics: imputer_stats
          )
        end
      end
    end

    def apply_transformations(df, config)
      imputers = initialize_imputers(config)

      standardize_config(config).each do |col, strategies|
        if df.columns.map(&:downcase).map(&:to_s).include?(col.downcase.to_s)
          actual_col = df.columns.map(&:to_s).find { |c| c.to_s.downcase == col.to_s.downcase }

          sorted_strategies(strategies).each do |strategy|
            conf = strategies[strategy.to_sym]
            if conf.is_a?(Hash) && conf.key?(:one_hot)
              df = apply_one_hot(df, col, imputers)
            else
              imputer = imputers.dig(col, strategy)
              df[actual_col] = imputer.transform(df[actual_col]) if imputer
            end
          end
        elsif @verbose
          puts "Warning: Column '#{col}' not found in DataFrame during apply_transformations process."
        end
      end

      df
    end

    def apply_one_hot(df, col, imputers)
      imputers = imputers.deep_symbolize_keys
      approved_values = if (cat_imputer = imputers.dig(col, :categorical)).present?
                          cat_imputer.statistics[:categorical][:value].select do |_k, v|
                            v >= cat_imputer.options[:categorical_min]
                          end.keys
                        else
                          df[col].uniq.to_a
                        end

      # Create one-hot encoded columns
      approved_values.each do |value|
        new_col_name = "#{col}_#{value}".gsub(/-/, "_")
        df = df.with_column(
          df[col].eq(value.to_s).cast(Polars::Int64).alias(new_col_name)
        )
      end

      # Create 'other' column for unapproved values
      other_col_name = "#{col}_other"
      df[other_col_name] = df[col].map_elements do |value|
        approved_values.map(&:to_s).exclude?(value)
      end.cast(Polars::Int64)
      df = df.drop([col.to_s])
      print df.columns
      puts
      df
    end

    def sorted_strategies(strategies)
      strategies.keys.sort_by do |key|
        PREPROCESSING_ORDER.index(key)
      end
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
  end
end
