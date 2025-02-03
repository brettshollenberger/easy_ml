module EasyML
  class Column
    class Imputers
      class OrdinalEncoder < Base
        param_applies :ordinal_encoding

        def transform(df)
          return df unless ordinal_encoding?

          binding.pry
          df = df.with_column(
            Polars.col(column.name).fill_null(1).alias(column.name)
          )
          df
        end

        def ordinal_encoding?
          params.dig(:ordinal_encoding)
        end
      end
    end
  end
end
