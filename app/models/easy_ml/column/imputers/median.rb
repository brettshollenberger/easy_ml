module EasyML
  class Column
    class Imputers
      class Median < Base
        method_applies :median

        def transform(df)
          return df unless median.present?

          df = df.with_column(
            Polars.col(column.name).fill_null(median).alias(column.name)
          )
          df
        end

        def median
          statistics(:median)
        end
      end
    end
  end
end
