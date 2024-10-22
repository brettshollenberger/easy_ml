module EasyML::Data::Dataset::Splitters
  class DateSplitter
    include GlueGun::DSL

    attribute :today, :datetime
    def today=(value)
      value = Time.zone.parse(value) if value.is_a?(String)
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

    def split(df)
      if df[date_col].dtype.is_a?(Polars::String)
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
