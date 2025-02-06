module EasyML
  class Column
    class Lineage
      attr_accessor :dataset, :column

      def initialize(column)
        @column = column
        @dataset = column.dataset
      end

      def sort_order
        [
          RawDataset,
          ComputedByFeature,
          Preprocessed,
        ]
      end

      def lineage
        sort_order.map do |cl|
          cl.new(column)
        end.select(&:check)
          .map(&:as_json)
          .compact
      end
    end
  end
end
