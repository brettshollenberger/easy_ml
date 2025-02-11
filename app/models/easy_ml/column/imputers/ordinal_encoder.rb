module EasyML
  class Column
    class Imputers
      class OrdinalEncoder < Base
        param_applies :ordinal_encoding

        def self.description
          "Ordinal encoder"
        end

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
            df[column.name].map { |v| label_encoder[column.cast(v)] || other_value }.alias(column.name)
          )

          df
        end

        def decode_labels(df)
          if df.is_a?(Array)
            return df.map { |v| label_decoder[v.to_i] }
          end

          df = df.with_column(
            df[column.name].map { |v| label_decoder[v.to_i] }.alias(column.name)
          )
          df
        end

        def categories
          label_encoder.keys
        end

        def values
          label_encoder.values
        end

        def cast_encoder(encoder)
          begin
            encoder.transform_keys { |k| column.cast(k) }
          rescue => e
            binding.pry
          end
        end

        def cast_decoder(decoder)
          decoder.transform_keys { |k| k.to_i }
        end

        def label_encoder
          @label_encoder ||= cast_encoder(statistics(:label_encoder))
        end

        def label_decoder
          @label_decoder ||= cast_decoder(statistics(:label_decoder))
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
