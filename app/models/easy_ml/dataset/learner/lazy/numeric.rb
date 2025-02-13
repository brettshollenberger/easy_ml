module EasyML
  class Dataset
    class Learner
      class Lazy
        class Numeric < Query
          def train_query
            super.concat([
              Polars.col(column.name).mean.alias("#{column.name}__mean"),
              Polars.col(column.name).median.alias("#{column.name}__median"),
              Polars.col(column.name).min.alias("#{column.name}__min"),
              Polars.col(column.name).max.alias("#{column.name}__max"),
              Polars.col(column.name).std.alias("#{column.name}__std"),
            ])
          end
        end
      end
    end
  end
end
