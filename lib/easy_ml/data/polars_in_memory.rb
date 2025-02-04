module EasyML
  module Data
    class PolarsInMemory
      attr_reader :df

      def initialize(df)
        @df = df
      end

      def self.query(df, **kwargs)
        new(df).query(**kwargs)
      end

      def query(drop_cols: [], filter: nil, limit: nil, select: nil, unique: nil, sort: nil, descending: false)
        return if df.nil?

        df = self.df.clone
        df = df.filter(filter) if filter
        select = df.columns & ([select] || []).flatten
        df = df.select(select) if select.present?
        df = df.unique if unique
        drop_cols &= df.columns
        df = df.drop(drop_cols) unless drop_cols.empty?
        df = df.sort(sort, reverse: descending) if sort
        df = df.limit(limit) if limit
        df
      end
    end
  end
end
