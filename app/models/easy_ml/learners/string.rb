module EasyML
  module Learners
    class String < Base
      def train_columns
        super.concat(
          %i(most_frequent_value unique_count)
        )
      end

      def statistics(df)
        return {} if df.nil?

        super(df).merge!({
          most_frequent_value: df[column.name].mode.sort.to_a&.first,
          unique_count: df[column.name].cast(:str).n_unique,
        })
      end
    end
  end
end
