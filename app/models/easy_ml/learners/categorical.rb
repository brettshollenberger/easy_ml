module EasyML
  module Learners
    class Categorical < Base
      def train_columns
        %i(most_frequent_value last_known_value allowed_categories label_encoder label_decoder)
      end

      def learn
        {
          raw: learn_split(column.raw),
          processed: learn_split(column.raw).merge!(
            null_count: 0,
          ),
        }
      end

      def statistics(df)
        super(df).merge!({
          most_frequent_value: df[column.name].mode.sort.to_a&.first,
          allowed_categories: allowed_categories(df),
        }.merge!(learn_encoder_decoder(df)))
      end

      def learn_encoder_decoder(df)
        value_counts = df[column.name].value_counts
        column_names = value_counts.columns
        value_column = column_names[0]
        count_column = column_names[1]

        as_hash = value_counts.select([value_column, count_column]).rows.to_a.to_h.transform_keys(&:to_s)
        label_encoder = as_hash.keys.sort.each.with_index.reduce({}) do |h, (k, i)|
          h.tap do
            h[k] = i
          end
        end
        label_decoder = label_encoder.invert

        {
          value: as_hash,
          label_encoder: label_encoder,
          label_decoder: label_decoder,
        }
      end

      def allowed_categories(df)
        val_counts = df[column.name].value_counts
        val_counts[val_counts["count"] >= column.categorical_min][column.name].to_a.compact.sort
      end
    end
  end
end
