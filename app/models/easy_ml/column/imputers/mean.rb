module EasyML
  class Column
    class Imputers
      class Mean < Base
        method_applies :mean

        def self.description
          "Mean imputation"
        end

        def transform(df)
          return df unless mean.present?

          mean = statistics(:mean)
          df = df.with_column(
            Polars.col(column.name).fill_null(mean).alias(column.name)
          )
          df
        end

        def mean
          statistics(:mean)
        end
      end
    end
  end
end
