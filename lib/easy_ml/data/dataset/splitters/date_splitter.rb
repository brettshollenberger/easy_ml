module EasyML::Data::Dataset::Splitters
  class DateSplitter
    attr_reader :today, :date_col, :months_test, :months_valid

    def initialize(today: UTC.now.to_date, date_col: nil, months_test: 2, months_valid: 2)
      @today = today.in_time_zone(UTC)
      @date_col = date_col
      @months_test = months_test
      @months_valid = months_valid
    end

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
