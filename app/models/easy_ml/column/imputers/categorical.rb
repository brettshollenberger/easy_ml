module EasyML
  class Column
    class Imputers
      class Categorical < Base
        method_applies :categorical
        param_applies :categorical_min

        def transform(df)
          return df unless allowed_categories.present?

          df = df.with_column(
            Polars.when(Polars.col(column.name).is_in(allowed_categories))
              .then(Polars.col(column.name))
              .otherwise(Polars.lit("other"))
              .alias(column.name)
          )
          df
        end

        def allowed_categories
          column.allowed_categories
        end
      end
    end
  end
end
