# == Schema Information
#
# Table name: easy_ml_splitters
#
#  id            :bigint           not null, primary key
#  splitter_type :string           not null
#  configuration :json
#  dataset_id    :bigint           not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
require_relative "splitter"

module EasyML
  class DateSplitter < EasyML::Splitter
    validates :date_col, presence: true
    validates :months_test, presence: true, numericality: { greater_than: 0 }
    validates :months_valid, presence: true, numericality: { greater_than: 0 }

    attr_accessor :today, :date_col, :months_test, :months_valid

    # def split
    #   reference_date = today || Time.current

    #   test_start = reference_date - months_test.months
    #   valid_start = test_start - months_valid.months

    #   {
    #     train: ->(df) { df[df[date_col] < valid_start] },
    #     validation: ->(df) { df[(df[date_col] >= valid_start) & (df[date_col] < test_start)] },
    #     test: ->(df) { df[df[date_col] >= test_start] }
    #   }
    # end
    # attribute :today, :datetime
    # def today=(value)
    #   value = UTC.parse(value) if value.is_a?(String)
    #   super(value.in_time_zone(UTC).to_datetime)
    # end
    # attribute :date_col, :string
    # attribute :date_format, :string, default: "%Y-%m-%d"
    # attribute :months_test, :integer, default: 2
    # attribute :months_valid, :integer, default: 2

    # def initialize(options)
    #   options[:today] ||= UTC.now
    #   super(options)
    # end
    def prepare(datasource)
      @datasource_end = datasource.query(sort: date_col, descending: true, limit: 1,
                                         select: date_col)[date_col]&.to_a&.first
    end

    def split(df)
      raise "Split by date requires argument: date_col" unless date_col.present?

      df = EasyML::Data::DateConverter.maybe_convert_date(df, date_col)

      unless df[date_col].dtype.is_a?(Polars::Datetime)
        raise "Date splitter cannot split on non-date col #{date_col}, dtype is #{df[date_col].dtype}"
      end

      validation_date_start, test_date_start = splits

      test_df = Polars.concat(
        [
          df.filter(Polars.col(date_col) >= test_date_start),
          df.filter(Polars.col(date_col).is_null)
        ]
      )
      remaining_df = df.filter(Polars.col(date_col) < test_date_start)
      valid_df = remaining_df.filter(Polars.col(date_col) >= validation_date_start)
      train_df = remaining_df.filter(Polars.col(date_col) < validation_date_start)

      [train_df, valid_df, test_df]
    end

    def months(n)
      ActiveSupport::Duration.months(n)
    end

    def splits
      reference_date = datasource_end || today
      test_date_start = reference_date.advance(months: -months_test).beginning_of_day
      validation_date_start = test_date_start.advance(months: -months_valid).beginning_of_day
      [validation_date_start, test_date_start]
    end

    def datasource_end
      return @datasource_end if @datasource_end

      @datasource_end = dataset.datasource.query(sort: date_col, descending: true, limit: 1,
                                                 select: date_col)[date_col]&.to_a&.first
    end

    def today
      case @today
      when String
        UTC.parse(@today)
      when NilClass
        UTC.today
      else
        @today
      end
    end
  end
end
