module EasyML
  module Splitters
    class BaseSplitter
      include ActiveModel::Validations
      include EasyML::Concerns::Configurable

      attr_reader :splitter

      def split(df, &block)
        split_df(df).tap do |splits|
          yield splits if block_given?
        end
      end

      def split_df(df)
        df
      end

      def initialize(splitter)
        @splitter = splitter
      end

      delegate :dataset, to: :splitter
    end
  end
end
