module EasyML
  module Splitters
    class BaseSplitter
      include ActiveModel::Validations
      include EasyML::Concerns::Configurable

      attr_reader :splitter

      def split_df(df)
        df
      end

      def split(dataset)
        split_df(dataset.materialized_view)
      end

      def initialize(splitter)
        @splitter = splitter
      end

      delegate :dataset, to: :splitter
    end
  end
end
