module EasyML
  module CoreExt
    module Hash
      def deep_compact
        each_with_object({}) do |(key, value), result|
          next if value.nil?

          compacted = if value.is_a?(Hash)
              value.deep_compact
            elsif value.is_a?(Array)
              value.map { |v| v.is_a?(Hash) ? v.deep_compact : v }.compact
            else
              value
            end

          result[key] = compacted unless compacted.blank?
        end
      end
    end
  end
end

# Extend Hash class with our custom method
Hash.include EasyML::CoreExt::Hash
