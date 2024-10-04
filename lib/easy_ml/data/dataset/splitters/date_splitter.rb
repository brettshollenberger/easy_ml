module EasyML::Data::Dataset::Splitters
  class DateSplitter
    include GlueGun::DSL

    attribute :today, :datetime
    def today=(value)
      super(value.in_time_zone(UTC).to_datetime)
    end
    attribute :date_col, :string
    attribute :months_test, :integer, default: 2
    attribute :months_valid, :integer, default: 2

    def initialize(options)
      options[:today] ||= UTC.now
      super(options)
    end

    def split(df)
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
