module EasyML
  class Column
    class Imputers
      class Mean < Base
        def transform(df)
          return df unless mean.present?

          df = df.with_column(
            Polars.col(column.name).fill_null(mean).alias(column.name)
          )
          df
        end

        def applies?
          method.to_sym == :mean
        end

        def mean
          column.statistics.dig(:clipped, :mean)
        end
      end
    end
  end
end
