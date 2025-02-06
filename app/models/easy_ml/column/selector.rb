module EasyML
  class Column
    class Selector
      attr_accessor :selected, :dataset, :column, :transform

      def initialize(column, selected = nil, &block)
        @column = column
        @dataset = column.dataset
        @selected = selected
        @transform = block
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

      def clipped
        Selector.new(column, :raw) do |df|
          column.imputers.training.clip(df)
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
        if column.is_computed?
          Selector.new(column, :processed).send(:select, :data, **kwargs)
        else
          select(:data, **kwargs)
        end
      end

      private

      def select(segment, **orig_kwargs)
        kwargs = orig_kwargs.clone
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
        kwargs[:select] = kwargs[:select].flatten.uniq

        if @selected.present?
          available_columns = dataset.send(@selected).send(segment, limit: 1, all_columns: true)&.columns || []
          kwargs[:select] = available_columns & kwargs[:select]
          return Polars::DataFrame.new if kwargs[:select].empty?
          result = dataset.send(@selected).send(segment, **kwargs)
        else
          available_columns = dataset.send(segment, limit: 1, all_columns: true)&.columns || []
          kwargs[:select] = available_columns & kwargs[:select]
          return Polars::DataFrame.new if kwargs[:select].empty?
          result = dataset.send(segment, **kwargs)
        end

        if transform
          result = transform.call(result)
        end

        result
      end
    end
  end
end
