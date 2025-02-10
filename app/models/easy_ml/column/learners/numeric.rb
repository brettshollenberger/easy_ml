module EasyML
  class Column
    module Learners
      class Numeric < Base
        def train_statistics(df)
          super(df).concat([
            Polars.col(column.name).mean.alias("mean"),
            Polars.col(column.name).median.alias("median"),
            Polars.col(column.name).min.alias("min"),
            Polars.col(column.name).max.alias("max"),
            Polars.col(column.name).std.alias("std"),
          ])
        end
      end
    end
  end
end
