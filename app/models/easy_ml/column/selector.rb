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
        if column.is_computed? && !column.in_raw_dataset?
          Selector.new(column, :processed)
        else
          Selector.new(column, :raw)
        end
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
        return nil if dataset.nil?

        kwargs[:all_columns] = true

        if kwargs.key?(:select)
          kwargs[:select] = [kwargs[:select]].flatten
        else
          kwargs[:select] = []
        end

        if (selected == :processed || (selected.nil? && !dataset.needs_refresh?)) && column.one_hot?
          kwargs[:select] << column.virtual_columns
        else
          kwargs[:select] << column.name
        end
        kwargs[:select] = kwargs[:select].uniq

        if @selected.present?
          dataset.send(@selected).send(segment, **kwargs)
        else
          dataset.send(segment, **kwargs)
        end
      end
    end
  end
end
