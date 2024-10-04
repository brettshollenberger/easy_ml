require "easy_ml/support/utc"
module EasyML::Data::Dataset::Splitters
  class DateSplitter
    include GlueGun::DSL

    attribute :today, :date, default: -> { UTC.now.to_date }
    def today=(value)
      super(value.in_time_zone(UTC))
    end
    attribute :date_col, :string
    attribute :months_test, :integer, default: 2
    attribute :months_valid, :integer, default: 2

    def split(df)
      test_date_start, validation_date_start = splits

      valid_df = df.filter(Polars.col(date_col) >= validation_date_start)
      remaining_df = df.filter(Polars.col(date_col) < validation_date_start)
      test_df = remaining_df.filter(Polars.col(date_col) >= test_date_start)
      train_df = remaining_df.filter(Polars.col(date_col) < test_date_start)

      [train_df, test_df, valid_df]
    end

    def splits
      validation_date_start = (today - months_valid.months).beginning_of_day
      test_date_start = (today - (months_test + months_valid).months).beginning_of_day
      [test_date_start, validation_date_start]
    end
  end
end
