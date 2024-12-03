module EasyML
  module Splitters
    class BaseSplitter
      include ActiveModel::Validations
      include EasyML::Concerns::Configurable

      attr_reader :splitter

      def split; end

      def initialize(splitter)
        @splitter = splitter
      end
    end
  end
end
