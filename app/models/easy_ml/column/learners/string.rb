module EasyML
  class Column
    module Learners
      class String < Base
        def full_dataset_columns
          super.concat(
            %i(unique_count)
          )
        end

        def statistics(df)
          return {} if df.nil?

          super(df).merge!({
            unique_count: df[column.name].cast(:str).n_unique,
          })
        end
      end
    end
  end
end
