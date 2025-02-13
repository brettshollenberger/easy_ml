module EasyML
  module DeepCompact
    refine ::Array do
      def deep_compact
        compact.map do |value|
          value.respond_to?(:deep_compact) ? value.deep_compact : value
        end
      end
    end

    refine ::Hash do
      def deep_compact
        compact.transform_values do |value|
          value.respond_to?(:deep_compact) ? value.deep_compact : value
        end
      end
    end
  end
end
