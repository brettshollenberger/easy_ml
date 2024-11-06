require_relative "date_converter"

module EasyML
  module Data
    module FieldTypeDetector
      module_function

      # Determines the semantic type of a field based on its data
      # @param series [Polars::Series] The series to analyze
      # @return [Symbol] One of :numeric, :datetime, :categorical, or :text
      def determine_type(series)
        dtype = series.dtype
        case dtype
        when Polars::Float64, Polars::Int64
          :numeric
        when Polars::Datetime
          :datetime
        when Polars::Utf8
          determine_string_type(series)
        else
          :categorical # Default fallback for unknown types
        end
      end

      # Determines if a string field is a date, text, or categorical
      # @param series [Polars::Series] The string series to analyze
      # @return [Symbol] One of :datetime, :text, or :categorical
      def determine_string_type(series)
        if DateConverter.maybe_convert_date(Polars::DataFrame.new({ temp: series }),
                                            :temp)[:temp].dtype.is_a?(Polars::Datetime)
          :datetime
        else
          categorical_or_text?(series)
        end
      end

      # Determines if a string field is categorical or free text
      # @param series [Polars::Series] The string series to analyze
      # @return [Symbol] Either :categorical or :text
      def categorical_or_text?(series)
        return :categorical if series.null_count == series.len

        # Calculate unique ratio excluding nulls
        non_null_count = series.len - series.null_count
        return :categorical if non_null_count == 0

        unique_ratio = series.n_unique.to_f / non_null_count

        # Heuristic: If more than 50% of values are unique, consider it text
        unique_ratio > 0.5 ? :text : :categorical
      end

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
