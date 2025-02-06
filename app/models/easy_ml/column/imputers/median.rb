module EasyML
  class Column
    class Imputers
      class Median < Base
        method_applies :median

        def self.description
          "Median imputation"
        end

        def transform(df)
          return df unless median.present?

          median = statistics(:median)
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
