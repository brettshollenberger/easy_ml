module EasyML
  class Column
    class Imputers
      class MostFrequent < Base
        method_applies :most_frequent

        def self.description
          "Most frequent value imputation"
        end

        def transform(df)
          return df unless most_frequent.present?

          most_frequent = statistics(:most_frequent_value)
          df = df.with_column(
            Polars.col(column.name).fill_null(most_frequent).alias(column.name)
          )
          df
        end

        def most_frequent
          statistics(:most_frequent_value)
        end
      end
    end
  end
end
