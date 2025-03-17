module EasyML
  module Data
    module DateConverter
      COMMON_DATE_FORMATS = [
        "%Y-%m-%d %H:%M:%S.%f %Z",
        "%Y-%m-%dT%H:%M:%S.%6N",   # e.g., "2021-01-01T00:00:00.000000"
        "%Y-%m-%d %H:%M:%S.%L Z",   # e.g., "2025-01-03 23:04:49.492 Z"
        "%Y-%m-%d %H:%M:%S.%L",     # e.g., "2021-01-01 00:01:36.000"
        "%Y-%m-%d %H:%M:%S",        # e.g., "2021-01-01 00:01:36"
        "%Y-%m-%d %H:%M",           # e.g., "2021-01-01 00:01"
        "%Y-%m-%d",                 # e.g., "2021-01-01"
        "%m/%d/%Y %H:%M:%S",        # e.g., "01/01/2021 00:01:36"
        "%m/%d/%Y",                 # e.g., "01/01/2021"
        "%d-%m-%Y",                 # e.g., "01-01-2021"
        "%d-%b-%Y %H:%M:%S",        # e.g., "01-Jan-2021 00:01:36"
        "%d-%b-%Y",                # e.g., "01-Jan-2021"
        "%b %d, %Y",               # e.g., "Jan 01, 2021"
        "%Y/%m/%d %H:%M:%S",        # e.g., "2021/01/01 00:01:36"
        "%Y/%m/%d",                # e.g., "2021/01/01"
      ].freeze

      def self.maybe_convert_date(df, column = nil)
        column = column.to_s if column.present?
        if df.is_a?(Polars::Series)
          column = "temp" if column.nil?
          df = Polars::DataFrame.new({ column.to_s => df })
        end
        return df unless df.columns.include?(column)
        return df if df[column].dtype.is_a?(Polars::Datetime)

        conversions = df.select(queries(column)).to_hashes&.first || []
        return df unless conversions.any?

        conversions = conversions.select { |k, v| v }
        return df unless conversions.any?

        conversions.map do |k, _|
          conversion = conversion(k)
          df = df.with_columns(conversion)
        end

        df
      end

      def self.queries(column)
        COMMON_DATE_FORMATS.map do |format|
          Polars.col(column)
                .cast(Polars::String)
                .str.strptime(Polars::Datetime, format, strict: false)
                .is_not_null()
                .sum()
                .eq(
                  Polars.col(column).is_not_null().sum()
                ).alias("convert_#{column}_to_#{format}")
        end
      end

      def self.conversion(key)
        key, ruby_type = key.split("convert_").last.split("_to_")
        Polars.col(key).cast(Polars::String).str.strptime(Polars::Datetime, ruby_type, strict: false).cast(Polars::Datetime).alias(key)
      end
    end
  end
end
