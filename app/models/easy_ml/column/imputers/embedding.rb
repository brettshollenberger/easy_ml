module EasyML
  class Column
    class Imputers
      class Embedding < Base
        method_applies :embedding

        def self.description
          "Generate embeddings"
        end

        def transform(df)
          return df unless allowed_categories.present?

          case column.datatype
          when :categorical
            df = df.with_column(
              Polars.when(Polars.col(column.name).is_in(allowed_categories))
                .then(Polars.col(column.name))
                .otherwise(Polars.lit("other"))
                .alias(column.name)
            )
          when :boolean
            # no-op
          end
          df
        end

        def allowed_categories
          column.allowed_categories
        end
      end
    end
  end
end
