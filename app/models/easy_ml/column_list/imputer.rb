module EasyML
  module ColumnList
    class Imputer
      attr_accessor :dataset, :df, :inference, :columns

      def initialize(dataset, df, columns: nil, imputers: [], inference: false)
        @dataset = dataset
        @df = df
        @columns = (columns.nil? || columns.empty?) ? dataset.columns : columns
        @inference = inference
        @_imputers = imputers
      end

      def imputers
        @imputers ||= columns.map { |column| inference ? column.imputers(@_imputers).inference : column.imputers(@_imputers).training }
      end

      def encode=(encode)
        imputers.each { |imputer| imputer.encode = encode }
      end

      def exprs
        imputers.flat_map(&:exprs).compact
      end
    end
  end
end
