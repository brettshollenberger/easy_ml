module EasyML
  class Column
    module Learners
      class Categorical < String
        def train_columns
          super.concat(
            %i(allowed_categories label_encoder label_decoder counts)
          )
        end

        def learn(type)
          types(type).each_with_object({}) do |type, h|
            h[type] = case type
              when :raw then learn_split(column.raw)
              when :processed then learn_split(column.raw).merge!(null_count: 0)
              end
          end
        end

        def statistics(df)
          return {} if df.nil?

          super(df).merge!({
            allowed_categories: allowed_categories(df),
            counts: df[column.name].value_counts.to_hash,
          }.merge!(learn_encoder_decoder(df)))
        end

        def learn_encoder_decoder(df)
          value_counts = df[column.name].value_counts
          column_names = value_counts.columns
          value_column = column_names[0]
          count_column = column_names[1]

          as_hash = value_counts.select([value_column, count_column]).rows.to_a.to_h.transform_keys(&column.method(:cast))
          label_encoder = as_hash.keys.compact.sort_by(&column.method(:sort_by)).each.with_index.reduce({}) do |h, (k, i)|
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
          val_counts[val_counts["count"] >= column.categorical_min][column.name].to_a.compact.sort_by(&column.method(:sort_by))
        end
      end
    end
  end
end
