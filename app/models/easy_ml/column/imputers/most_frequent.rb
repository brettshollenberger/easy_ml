module EasyML
  class Column
    class Imputers
      class MostFrequent < Base
        method_applies :most_frequent

        def transform(df)
          return df unless most_frequent.present?

          df = df.with_column(
            Polars.col(column.name).fill_null(most_frequent).alias(column.name)
          )
          df
        end

        def most_frequent
          column.statistics.dig(:clipped, :most_frequent_value) || column.statistics.dig(:raw, :most_frequent_value)
        end
      end
    end
  end
end
