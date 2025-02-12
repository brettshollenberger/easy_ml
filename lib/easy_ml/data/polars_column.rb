require_relative "date_converter"

module EasyML
  module Data
    class PolarsColumn
      TYPE_MAP = {
        float: Polars::Float64,
        integer: Polars::Int64,
        boolean: Polars::Boolean,
        datetime: Polars::Datetime,
        date: Polars::Date,
        string: Polars::String,
        text: Polars::String,
        categorical: Polars::Categorical,
        null: Polars::Null,
      }
      POLARS_MAP = {
        Polars::Float64 => :float,
        Polars::Int64 => :integer,
        Polars::Float32 => :float,
        Polars::Int32 => :integer,
        Polars::Boolean => :boolean,
        Polars::Datetime => :datetime,
        Polars::Date => :date,
        Polars::String => :string,
        Polars::Categorical => :categorical,
        Polars::Null => :null,
      }.stringify_keys
      include EasyML::Timing

      class << self
        def polars_to_sym(polars_type)
          new.polars_to_sym(polars_type)
        end

        def determine_type(series, polars_type = false)
          new.determine_type(series, polars_type)
        end

        def parse_polars_dtype(dtype_string)
          new.parse_polars_dtype(dtype_string)
        end

        def get_polars_type(dtype)
          new.get_polars_type(dtype)
        end

        def polars_dtype_to_sym(dtype_string)
          new.polars_dtype_to_sym(dtype_string)
        end

        def sym_to_polars(symbol)
          new.sym_to_polars(symbol)
        end
      end

      def polars_to_sym(polars_type)
        return nil if polars_type.nil?

        if polars_type.is_a?(Polars::DataType)
          POLARS_MAP.dig(polars_type.class.to_s)
        else
          polars_type.to_sym if TYPE_MAP.keys.include?(polars_type.to_sym)
        end
      end

      def parse_polars_dtype(dtype_string)
        case dtype_string
        when /^Polars::Datetime/
          time_unit = dtype_string[/time_unit: "(.*?)"/, 1]
          time_zone = dtype_string[/time_zone: (.*)?\)/, 1]
          time_zone = time_zone == "nil" ? nil : time_zone&.delete('"')
          Polars::Datetime.new(time_unit, time_zone)
        when /^Polars::/
          Polars.const_get(dtype_string.split("::").last)
        else
          raise ArgumentError, "Unknown Polars data type: #{dtype_string}"
        end
      end

      def sym_to_polars(symbol)
        TYPE_MAP.dig(symbol.to_sym)
      end

      # Determines the semantic type of a field based on its data
      # @param series [Polars::Series] The series to analyze
      # @return [Symbol] One of :numeric, :datetime, :categorical, or :text
      def determine_type(series, polars_type = false)
        dtype = series.dtype

        if dtype.is_a?(Polars::Utf8)
          string_type = determine_string_type(series)
          if string_type == :datetime
            date = EasyML::Data::DateConverter.maybe_convert_date(series)
            return polars_type ? date[date.columns.first].dtype : :datetime
          end
        end

        type_name = case dtype
          when Polars::Float64
            :float
          when Polars::Int64
            :integer
          when Polars::Datetime
            :datetime
          when Polars::Date
            :date
          when Polars::Boolean
            :boolean
          when Polars::Utf8
            determine_string_type(series)
          when Polars::Null
            :null
          else
            :categorical
          end

        polars_type ? sym_to_polars(type_name) : type_name
      end

      measure_method_timing :determine_type

      # Determines if a string field is a date, text, or categorical
      # @param series [Polars::Series] The string series to analyze
      # @return [Symbol] One of :datetime, :text, or :categorical
      def determine_string_type(series)
        if EasyML::Data::DateConverter.maybe_convert_date(Polars::DataFrame.new({ temp: series }),
                                                          :temp)[:temp].dtype.is_a?(Polars::Datetime)
          :datetime
        else
          categorical_or_text?(series)
        end
      end

      measure_method_timing :determine_string_type

      # Determines if a string field is categorical or free text
      # @param series [Polars::Series] The string series to analyze
      # @return [Symbol] Either :categorical or :text
      def categorical_or_text?(series)
        return :categorical if series.null_count == series.len

        # Get non-null count for percentage calculations
        non_null_count = series.len - series.null_count
        return :categorical if non_null_count == 0

        # Get value counts as percentages
        value_counts = series.value_counts(parallel: true)
        percentages = value_counts.with_column(
          (value_counts["count"] / non_null_count.to_f * 100).alias("percentage")
        )

        # Check if any category represents more than 10% of the data
        max_percentage = percentages["percentage"].max
        return :text if max_percentage < 10.0

        # Calculate average percentage per category
        avg_percentage = 100.0 / series.n_unique

        # If average category represents less than 1% of data, it's likely text
        avg_percentage < 1.0 ? :text : :categorical
      end

      measure_method_timing :categorical_or_text?

      # Returns whether the field type is numeric
      # @param field_type [Symbol] The field type to check
      # @return [Boolean]
      def numeric?(field_type)
        field_type == :numeric
      end

      # Returns whether the field type is categorical
      # @param field_type [Symbol] The field type to check
      # @return [Boolean]
      def categorical?(field_type)
        field_type == :categorical
      end

      # Returns whether the field type is datetime
      # @param field_type [Symbol] The field type to check
      # @return [Boolean]
      def datetime?(field_type)
        field_type == :datetime
      end

      # Returns whether the field type is text
      # @param field_type [Symbol] The field type to check
      # @return [Boolean]
      def text?(field_type)
        field_type == :text
      end
    end
  end
end
