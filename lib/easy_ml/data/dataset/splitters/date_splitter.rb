module EasyML::Data::Dataset::Splitters
  class DateSplitter
    include GlueGun::DSL

    attribute :today, :datetime
    def today=(value)
      value = UTC.parse(value) if value.is_a?(String)
      super(value.in_time_zone(UTC).to_datetime)
    end
    attribute :date_col, :string
    attribute :date_format, :string, default: "%Y-%m-%d"
    attribute :months_test, :integer, default: 2
    attribute :months_valid, :integer, default: 2

    def initialize(options)
      options[:today] ||= UTC.now
      super(options)
    end

    def detect_date_format(date_strings)
      # Define common date-time formats to check
      common_formats = [
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
      ]

      # Iterate over formats and test each one
      shared_format = common_formats.detect do |format|
        # Attempt to parse each date string using the current format
        date_strings.all? do |date_str|
          DateTime.strptime(date_str, format)
          true
        rescue StandardError
          false
        end
      end
      ruby_to_polars_format(shared_format)
    end

    def ruby_to_polars_format(ruby_format)
      # Replace Ruby's '%L' (milliseconds) with Polars' '%3f'
      ruby_format.gsub("%L", "%3f")
    end

    def split(df)
      raise "Split by date requires argument: date_col" unless date_col.present?

      if df[date_col].dtype.is_a?(Polars::String)
        self.date_format = detect_date_format(df[date_col].to_a)
        df = df.with_column(
          Polars.col(date_col).str.strptime(Polars::Datetime, date_format).alias(date_col)
        )
      end
      unless df[date_col].dtype.is_a?(Polars::Datetime)
        raise "Date splitter cannot split on non-date col #{date_col}, dtype is #{df[date_col].dtype}"
      end

      validation_date_start, test_date_start = splits

      test_df = df.filter(Polars.col(date_col) >= test_date_start)
      remaining_df = df.filter(Polars.col(date_col) < test_date_start)
      valid_df = remaining_df.filter(Polars.col(date_col) >= validation_date_start)
      train_df = remaining_df.filter(Polars.col(date_col) < validation_date_start)

      [train_df, valid_df, test_df]
    end

    def months(n)
      ActiveSupport::Duration.months(n)
    end

    def splits
      test_date_start = today.advance(months: -months_test).beginning_of_day
      validation_date_start = today.advance(months: -(months_test + months_valid)).beginning_of_day
      [validation_date_start, test_date_start]
    end
  end
end
