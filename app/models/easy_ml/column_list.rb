module EasyML
  module ColumnList
    def one_hots
      column_list.select(&:one_hot?)
    end

    def allowed_categories
      one_hots.reduce({}) do |h, col|
        h.tap do
          h[col.name] = col.allowed_categories
        end
      end
    end

    def one_hot?(column)
      one_hots.map(&:name).detect do |one_hot_col|
        column.start_with?(one_hot_col)
      end
    end

    def virtual_column?(column)
      false
    end

    # columns = ["a", "b", "c"]
    def syncable
      dataset.processed_schema.keys.select do |col|
        !one_hot?(col) &&
          !virtual_column?(col)
      end
    end

    def column_list
      self
    end

    def dataset
      proxy_association.owner
    end
  end
end
