module EasyML
  class Column
    module Learners
      class Numeric < Base
        def train_statistics(df)
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
            sorted_df = df.sort(dataset.date_column.name, reverse: true)
            last_value = sorted_df
              .filter(Polars.col(column.name).is_not_null)
              .select(column.name)
              .head(1)
              .item

            last_value
          end
        end
      end
    end
  end
end
