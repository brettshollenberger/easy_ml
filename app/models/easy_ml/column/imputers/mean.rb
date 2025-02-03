module EasyML
  class Column
    class Imputers
      class Mean < Base
        method_applies :mean

        def transform(df)
          return df unless mean.present?

          df = df.with_column(
            Polars.col(column.name).fill_null(mean).alias(column.name)
          )
          df
        end

        def mean
          column.statistics.dig(:clipped, :mean) || column.statistics.dig(:raw, :mean)
        end
      end
    end
  end
end
