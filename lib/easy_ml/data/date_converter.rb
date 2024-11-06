module EasyML
  module Data
    module DateConverter
      COMMON_DATE_FORMATS = [
        "%Y-%m-%d %H:%M:%S.%L",   # e.g., "2021-01-01 00:01:36.000"
        "%Y-%m-%d %H:%M:%S",      # e.g., "2021-01-01 00:01:36"
        "%Y-%m-%d %H:%M",         # e.g., "2021-01-01 00:01"
        "%Y-%m-%d",               # e.g., "2021-01-01"
        "%m/%d/%Y %H:%M:%S",      # e.g., "01/01/2021 00:01:36"
        "%m/%d/%Y",               # e.g., "01/01/2021"
        "%d-%m-%Y",               # e.g., "01-01-2021"
        "%d-%b-%Y %H:%M:%S",      # e.g., "01-Jan-2021 00:01:36"
        "%d-%b-%Y",               # e.g., "01-Jan-2021"
        "%b %d, %Y",              # e.g., "Jan 01, 2021"
        "%Y/%m/%d %H:%M:%S",      # e.g., "2021/01/01 00:01:36"
        "%Y/%m/%d"                # e.g., "2021/01/01"
      ].freeze

      FORMAT_MAPPINGS = {
        ruby_to_polars: {
          "%L" => "%3f" # milliseconds
        }
      }.freeze

      class << self
        # Attempts to convert a string column to datetime if it appears to be a date
        # @param df [Polars::DataFrame] The dataframe containing the series
        # @param column [String] The name of the column to convert
        # @return [Polars::DataFrame] The dataframe with converted column (if successful)
        def maybe_convert_date(df, column = nil)
          if column.nil?
            series = df
            column = series.name
            df = Polars::DataFrame.new(series)
          else
            series = df[column]
          end
          return df if series.dtype.is_a?(Polars::Datetime)
          return df unless series.dtype == Polars::Utf8

          format = detect_polars_format(series)
          return df unless format

          df.with_column(
            Polars.col(column.to_s).str.strptime(Polars::Datetime, format).alias(column.to_s)
          )
        end

        private

        def detect_polars_format(series)
          return nil unless series.is_a?(Polars::Series)

          sample = series.filter(series.is_not_null).head(100).to_a
          ruby_format = detect_date_format(sample)
          convert_format(:ruby_to_polars, ruby_format)
        end

        def detect_date_format(date_strings)
          return nil if date_strings.empty?

          sample = date_strings.compact.sample([100, date_strings.length].min)

          COMMON_DATE_FORMATS.detect do |format|
            sample.all? do |date_str|
              DateTime.strptime(date_str, format)
              true
            rescue StandardError
              false
            end
          end
        end

        def convert_format(conversion, format)
          return nil if format.nil?

          result = format.dup
          FORMAT_MAPPINGS[conversion].each do |from, to|
            result = result.gsub(from, to)
          end
          result
        end
      end
    end
  end
end
