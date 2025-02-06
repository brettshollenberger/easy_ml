module EasyML
  class Column
    class Imputers
      class Clip < Base
        attr_accessor :column, :dataset, :preprocessing_step

        param_applies :clip

        def self.description
          "Clip"
        end

        def transform(df)
          df = df.with_column(
            Polars.col(column.name).clip(min, max).alias(column.name)
          )
          df
        end

        def min
          params.dig(:clip, :min) || 0
        end

        def max
          params.dig(:clip, :max) || Float::INFINITY
        end
      end
    end
  end
end
