module EasyML
  class Column
    class Imputers
      class Today < Base
        method_applies :today

        def transform(df)
          df = df.with_column(
            Polars.col(column.name).fill_null(Polars.lit(UTC.today.beginning_of_day)).alias(column.name)
          )
          df
        end
      end
    end
  end
end
