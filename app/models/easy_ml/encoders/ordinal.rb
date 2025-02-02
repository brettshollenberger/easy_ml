module EasyML
  module Encoders
    class Ordinal < Base
      def encode(column)
        approved_values = statistics.dig(col, :allowed_categories)

        df.with_column(
          df[col].map_elements do |value|
            approved_values.map(&:to_s).exclude?(value) ? "other" : value
          end.alias(col.to_s)
        )

        label_encoder = statistics.dig(col, :label_encoder).stringify_keys
        other_value = label_encoder.values.max + 1
        label_encoder["other"] = other_value
        df.with_column(
          df[col].map { |v| label_encoder[v.to_s] }.alias(col.to_s)
        )
      end
    end
  end
end
