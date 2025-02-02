module EasyML
  class Column
    class Selector
      attr_accessor :selected, :dataset, :column

      def initialize(column)
        @column = column
        @dataset = column.dataset
      end

      def name
        column.name
      end

      def raw
        @selected = dataset.raw
        self
      end

      def processed
        @selected = dataset.processed
        self
      end

      def train(**kwargs)
        base_action(:train, **kwargs)
      end

      def test(**kwargs)
        base_action(:test, **kwargs)
      end

      def valid(**kwargs)
        base_action(:valid, **kwargs)
      end

      def data(**kwargs)
        base_action(:data, **kwargs)
      end

      private

      def base_action(segment, **kwargs)
        kwargs.merge!(
          all_columns: true,
          select: name,
        )

        @selected.send(segment, **kwargs)
      end
    end
  end
end
