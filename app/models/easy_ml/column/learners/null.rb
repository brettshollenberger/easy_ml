module EasyML
  class Column
    module Learners
      class Null < Base
        def statistics(df)
          return {} if df.nil?

          {
            num_rows: df.size,
            null_count: df[column.name].null_count || 0,
            last_value: last_value(df),
          }
        end

        def full_dataset_columns
          %i(num_rows null_count)
        end

        def train_columns
          %i(last_value)
        end
      end
    end
  end
end
