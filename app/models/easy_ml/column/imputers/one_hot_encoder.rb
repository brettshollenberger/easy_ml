module EasyML
  class Column
    class Imputers
      class OneHotEncoder < Base
        param_applies :one_hot

        def self.description
          "One-hot encoder"
        end

        def transform(df)
          return df unless allowed_categories.present?

          allowed_categories.each do |value|
            new_col_name = "#{column.name}_#{value}".gsub(/-/, "_")
            df = df.with_column(
              df[column.name].cast(Polars::String).eq(value.to_s).cast(Polars::Boolean).alias(new_col_name)
            )
          end
          df = df.drop([column.name])
          df
        end

        def allowed_categories
          column.allowed_categories.sort
        end
      end
    end
  end
end
