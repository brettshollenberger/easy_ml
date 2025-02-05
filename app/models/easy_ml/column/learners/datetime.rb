module EasyML
  class Column
    module Learners
      class Datetime < Base
        def full_dataset_statistics(df)
          return {} if df.nil?

          super(df).merge!({
            unique_count: df[column.name].n_unique,
          })
        end

        def last_value(df)
          df[column.name].sort[-1]
        end
      end
    end
  end
end
