module EasyML
  class Dataset
    class Learner
      class Eager
        class Categorical < Query
          def train_query(df)
            {
              counts: counts(df).to_hash,
              allowed_categories: allowed_categories(df).to_series.to_a,
            }.merge!(
              learn_encoder_decoder(df)
            )
          end

          def learn_encoder_decoder(df)
            unsorted = allowed_categories(df).lazy.with_row_count.collect.to_hash.invert

            label_encoder = unsorted.transform_keys(&column.method(:cast)).keys.compact.sort_by(&column.method(:sort_by)).each.with_index.reduce({}) do |h, (k, i)|
              h.tap do
                h[k] = i
              end
            end
            label_decoder = label_encoder.invert

            {
              label_encoder: label_encoder,
              label_decoder: label_decoder,
            }
          end

          def counts(df)
            return @counts if @counts

            @counts = df.group_by(column.name)
                        .agg(Polars.col(column.name).count.alias("count"))
          end

          def allowed_categories(df)
            return @allowed_categories if @allowed_categories

            @allowed_categories = df.join(counts(df), on: column.name)
              .filter(Polars.col("count").gt(column.categorical_min))
              .select(column.name)
              .unique
              .sort(column.name, reverse: true)
          end
        end
      end
    end
  end
end
