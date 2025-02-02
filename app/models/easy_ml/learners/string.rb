module EasyML
  module Learners
    class String < Base
      def train_columns
        super.concat(
          %i(most_frequent_value)
        )
      end

      def statistics(df)
        super(df).merge!({
          most_frequent_value: df[column.name].mode.sort.to_a&.first,
        })
      end
    end
  end
end
