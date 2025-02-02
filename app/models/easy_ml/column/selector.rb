module EasyML
  class Column
    class Selector
      attr_accessor :selected, :dataset, :column

      def initialize(column, selected = nil)
        @column = column
        @dataset = column.dataset
        @selected = selected
      end

      def name
        column.name
      end

      def raw
        Selector.new(column, :raw)
      end

      def processed
        Selector.new(column, :processed)
      end

      def train(**kwargs)
        select(:train, **kwargs)
      end

      def test(**kwargs)
        select(:test, **kwargs)
      end

      def valid(**kwargs)
        select(:valid, **kwargs)
      end

      def data(**kwargs)
        select(:data, **kwargs)
      end

      private

      def select(segment, **kwargs)
        if (selected == :processed || (selected.nil? && !dataset.needs_refresh?)) && column.one_hot?
          kwargs.merge!(
            all_columns: true,
            select: column.virtual_columns,
          )
        else
          kwargs.merge!(
            all_columns: true,
            select: name,
          )
        end

        if @selected.present?
          dataset.send(selected).send(segment, **kwargs)
        else
          dataset.send(segment, **kwargs)
        end
      end
    end
  end
end
