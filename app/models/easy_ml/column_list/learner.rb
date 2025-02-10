module EasyML
  module ColumnList
    class Learner
      attr_accessor :dataset, :column

      def initialize(column)
        @column = column
        @dataset = column.dataset
      end

      def learner
        @learner ||= EasyML::Column::Learners::Base.adapter(column).new(column)
      end

      delegate :learn, to: :learner
    end
  end
end
