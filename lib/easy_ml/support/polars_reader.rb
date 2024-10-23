module EasyML
  class PolarsReader
    include GlueGun::DSL

    attribute :files
    attribute :polars_args, :hash, default: {}

    def normalize
      # Learn schema
      # Update raw files with schema / transform to Parquet files which maintain this schema?
      # Send back the raw data / not CSVs
      binding.pry
    end

    private

    def schema
      polars_args[:dtypes]
    end

    def cast(df)
      cast_cols = schema.keys & df.columns
      df = df.with_columns(
        cast_cols.map do |column|
          dtype = schema[column]
          df[column].cast(dtype).alias(column)
        end
      )
    end

    # List of file paths, these will be csvs
    def learn_schema(files)
      combined_schema = {}

      files.each do |file|
        df = Polars.read_csv(file, **polars_args)

        df.schema.each do |column, dtype|
          combined_schema[column] = if combined_schema.key?(column)
                                      resolve_dtype(combined_schema[column], dtype)
                                    else
                                      dtype
                                    end
        end
      end

      polars_args[:dtypes] = combined_schema
    end

    def resolve_dtype(dtype1, dtype2)
      # Example of simple rules: prioritize Float64 over Int64
      if [dtype1, dtype2].include?(:float64)
        :float64
      elsif [dtype1, dtype2].include?(:int64)
        :int64
      else
        # If both are the same, return any
        dtype1
      end
    end
  end
end
