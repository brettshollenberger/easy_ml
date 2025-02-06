module EasyML
  class Column
    class Imputers
      class Constant < Base
        method_applies :constant
        param_applies :constant

        def self.description
          "Constant value imputation"
        end

        def transform(df)
          return df unless constant.present?

          df = df.with_column(
            Polars.col(column.name).fill_null(constant).alias(column.name)
          )
          df
        end

        def constant
          params.dig(:constant)
        end
      end
    end
  end
end
