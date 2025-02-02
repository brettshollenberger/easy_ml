module EasyML
  class Column
    class Learner
      attr_accessor :dataset, :column

      def initialize(column)
        @column = column
        @dataset = column.dataset
      end

      def learner
        @learner ||= EasyML::Learners::Base.adapter(column).new(column)
      end

      delegate :learn, to: :learner
    end
  end
end
