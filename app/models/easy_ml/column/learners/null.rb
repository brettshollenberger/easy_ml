module EasyML
  class Column
    module Learners
      class Null < Base
        def full_dataset_statistics(df)
          return {} if df.nil?

          {
            num_rows: df.size,
            null_count: df[column.name].null_count || 0,
          }
        end

        def train_statistics(df)
          {
            last_value: last_value(df),
          }
        end
      end
    end
  end
end
