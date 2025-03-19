module EasyML
  class Dataset
    class Learner
      class Lazy
        class Numeric < Query
          def train_query
            super.concat([
              Polars.col(column.name)
                    .cast(datatype)
                    .mean
                    .alias("#{column.name}__mean"),

              Polars.col(column.name)
                      .cast(datatype)
                      .median
                      .alias("#{column.name}__median"),

              Polars.col(column.name)
                    .cast(datatype)
                    .min
                    .alias("#{column.name}__min"),

              Polars.col(column.name)
                    .cast(datatype)
                    .max
                    .alias("#{column.name}__max"),

              Polars.col(column.name)
                    .cast(datatype)
                    .std
                    .alias("#{column.name}__std"),
            ])
          end
        end
      end
    end
  end
end
