module EasyML
  class Column
    class Imputers
      class OrdinalEncoder < Base
        param_applies :ordinal_encoding

        def transform(df)
          return df unless label_encoder.present?

          case column.datatype
          when :categorical
            df = df.with_column(
              Polars.when(Polars.col(column.name).is_in(allowed_categories))
                .then(Polars.col(column.name))
                .otherwise(Polars.lit("other"))
                .alias(column.name)
            )
          when :boolean
            # no-op
          end

          df = df.with_column(
            df[column.name].map { |v| label_encoder[v.to_s] || other_value }.alias(column.name)
          )

          df
        end

        def decode_labels(df)
          if df.is_a?(Array)
            return df.map { |v| label_decoder[v.to_s] || "other" }
          end

          df = df.with_column(
            df[column.name].map { |v| label_decoder[v.to_s] || "other" }.alias(column.name)
          )
          df
        end

        def categories
          label_encoder.keys
        end

        def values
          label_encoder.values
        end

        def label_encoder
          begin
            @label_encoder ||= statistics(:label_encoder).stringify_keys
          rescue => e
            binding.pry
          end
        end

        def label_decoder
          @label_decoder ||= statistics(:label_decoder).stringify_keys
        end

        def other_value
          label_encoder.values.max + 1
        end

        def allowed_categories
          column.allowed_categories
        end
      end
    end
  end
end
