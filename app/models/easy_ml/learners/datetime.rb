module EasyML
  module Learners
    class Datetime < Base
      def last_value(df)
        df[column.name].sort[-1]
      end
    end
  end
end
