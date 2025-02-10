module EasyML
  class Column
    module Learners
      class Numeric < Base
        def train_statistics(df)
          super(df).concat([
            Polars.col(column.name).mean.alias("#{column.name}_mean"),
            Polars.col(column.name).median.alias("#{column.name}_median"),
            Polars.col(column.name).min.alias("#{column.name}_min"),
            Polars.col(column.name).max.alias("#{column.name}_max"),
            Polars.col(column.name).std.alias("#{column.name}_std"),
          ])
        end
      end
    end
  end
end
