module EasyML
  module Data
    module DateConverter
      COMMON_DATE_FORMATS = [
        "%Y-%m-%dT%H:%M:%S.%6N",   # e.g., "2021-01-01T00:00:00.000000"
        "%Y-%m-%d %H:%M:%S.%L Z",   # e.g., "2025-01-03 23:04:49.492 Z"
        "%Y-%m-%d %H:%M:%S.%L",     # e.g., "2021-01-01 00:01:36.000"
        "%Y-%m-%d %H:%M:%S.%L",     # duplicate format intentionally
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

      FORMAT_MAPPINGS = {
        ruby_to_polars: {
          "%L" => "%3f",  # milliseconds
          "%6N" => "%6f",  # microseconds
          "%N" => "%9f",  # nanoseconds
        },
      }.freeze

      class << self
        # Infers a strftime format string from the given date string.
        #
        # @param date_str [String] The date string to analyze.
        # @return [String, nil] The corresponding strftime format if recognized, or nil if not.
        def infer_strftime_format(date_str)
          return nil if date_str.blank?

          # YYYY-MM-DD (e.g., "2021-01-01")
          return "%Y-%m-%d" if date_str =~ /^\d{4}-\d{2}-\d{2}$/

          # YYYY/MM/DD (e.g., "2021/01/01")
          return "%Y/%m/%d" if date_str =~ /^\d{4}\/\d{2}\/\d{2}$/

          # Date & time with T separator (ISO 8601-like)
          if date_str.include?("T")
            # Without fractional seconds, e.g., "2021-01-01T12:34:56"
            return "%Y-%m-%dT%H:%M:%S" if date_str =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}$/

            # With fractional seconds, e.g., "2021-01-01T12:34:56.789" or "2021-01-01T12:34:56.123456"
            if date_str =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.(\d+)$/
              fraction = Regexp.last_match(1)
              case fraction.length
              when 3 then return "%Y-%m-%dT%H:%M:%S.%L"  # milliseconds
              when 6 then return "%Y-%m-%dT%H:%M:%S.%6N" # microseconds
              when 9 then return "%Y-%m-%dT%H:%M:%S.%N"  # nanoseconds
              else
                # Fallback if fractional part has unexpected length:
                return "%Y-%m-%dT%H:%M:%S.%N"
              end
            end
          end

          # Date & time with space separator
          if date_str.include?(" ")
            # Without fractional seconds, e.g., "2021-01-01 12:34:56"
            return "%Y-%m-%d %H:%M:%S" if date_str =~ /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/

            # With fractional seconds, e.g., "2021-01-01 12:34:56.789"
            if date_str =~ /^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.(\d+)$/
              fraction = Regexp.last_match(1)
              case fraction.length
              when 3 then return "%Y-%m-%d %H:%M:%S.%L"
              when 6 then return "%Y-%m-%d %H:%M:%S.%6N"
              when 9 then return "%Y-%m-%d %H:%M:%S.%N"
              else
                return "%Y-%m-%d %H:%M:%S.%N"
              end
            end
          end

          # Common US-style formats

          # MM/DD/YYYY (e.g., "01/31/2021")
          return "%m/%d/%Y" if date_str =~ /^\d{2}\/\d{2}\/\d{4}$/

          # DD-MM-YYYY (e.g., "31-01-2021")
          return "%d-%m-%Y" if date_str =~ /^\d{2}-\d{2}-\d{4}$/

          # DD-Mon-YYYY (e.g., "31-Jan-2021")
          return "%d-%b-%Y" if date_str =~ /^\d{2}-[A-Za-z]{3}-\d{4}$/

          # Mon DD, YYYY (e.g., "Jan 31, 2021")
          return "%b %d, %Y" if date_str =~ /^[A-Za-z]{3} \d{2}, \d{4}$/

          # Could add additional heuristics as needed...

          nil  # Return nil if no known format matches.
        end

        # Attempts to convert a string column to datetime if it appears to be a date.
        # @param df [Polars::DataFrame] The dataframe containing the series.
        # @param column [String] The name of the column to convert.
        # @return [Polars::DataFrame] The dataframe with the converted column (if successful).
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

          sample = series.filter(series.is_not_null).head(100).to_a
          ruby_format = detect_date_format(sample)

          if ruby_format
            format = convert_format(:ruby_to_polars, ruby_format)
            df = try_format(df, column, format)

            if df.filter(Polars.col("TRY").is_null).count > df.filter(Polars.col(column.to_s).is_null).count
              df = df.drop("TRY")
              best_format = df[column.to_s][0..100].to_a.count_by do |date_str|
                infer_strftime_format(date_str)
              end.max_by { |_format, count| count }[0]
              df = try_format(df, column, best_format)
            end

            df = df.with_column(df["TRY"].alias(column.to_s)).drop("TRY")
          end

          df
        end

        private

        def try_format(df, column, format)
          df = df.with_column(
            Polars.col(column.to_s)
              .str
              .strptime(Polars::Datetime, format, strict: false)
              .alias("TRY")
          )
        end

        def detect_polars_format(series)
          return nil unless series.is_a?(Polars::Series)

          sample = series.filter(series.is_not_null).head(100).to_a
          ruby_format = detect_date_format(sample)
          convert_format(:ruby_to_polars, ruby_format)
        end

        def detect_date_format(date_strings)
          return nil if date_strings.empty?

          sample = date_strings.compact.sample([100, date_strings.length].min)

          best_format = nil
          best_success_rate = 0.0
          sample_count = sample.length

          COMMON_DATE_FORMATS.each do |fmt|
            success_count = sample.count do |date_str|
              begin
                DateTime.strptime(date_str, fmt)
                true
              rescue StandardError
                false
              end
            end
            success_rate = success_count.to_f / sample_count
            if success_rate > best_success_rate
              best_success_rate = success_rate
              best_format = fmt
            end
            # If every sample string matches this format, return it immediately.
            return fmt if success_rate == 1.0
          end

          best_success_rate >= 0.8 ? best_format : nil
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
