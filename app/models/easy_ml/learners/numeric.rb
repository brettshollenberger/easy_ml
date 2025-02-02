module EasyML
  module Learners
    class Numeric < Base
      def train_columns
        super.concat(
          %i(mean median min max std last_value)
        )
      end

      def statistics(df)
        return {} if df.nil?

        super(df).merge!({
          mean: df[column.name].mean,
          median: df[column.name].median,
          min: df[column.name].min,
          max: df[column.name].max,
          std: df[column.name].std,
          last_value: last_value(df),
        }.compact)
      end

      def last_value(df)
        if dataset.date_column.present?
          df.filter(Polars.col(column.name).is_not_null)
            .sort(dataset.date_column.name)[column.name][-1]
          # sorted_df = df.sort(date_col, reverse: true)
          # last_value = sorted_df
          #   .filter(Polars.col(col).is_not_null)
          #   .select(col)
          #   .head(1)
          #   .item

          # last_value
        end
      end
    end
  end
end
