module EasyML
  class Column
    class Imputers
      class Ffill < Base
        method_applies :ffill

        def self.description
          "Forward fill imputation"
        end

        def transform(df)
          return df unless last_value.present?

          df = df.with_column(
            Polars.when(Polars.col(column.name).is_null)
                  .then(Polars.lit(last_value).cast(column.polars_datatype))
                  .otherwise(Polars.col(column.name).cast(column.polars_datatype))
                  .alias(column.name)
          )
          df
        end

        def last_value
          statistics(:last_value)
        end
      end
    end
  end
end
