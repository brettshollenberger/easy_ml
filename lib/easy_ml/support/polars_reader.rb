module EasyML
  class PolarsReader
    include GlueGun::DSL

    attribute :root_dir
    attribute :polars_args, :hash, default: {}

    def normalize
      return files if all_parquet?

      learn_schema
      convert_to_parquet
      files
    end

    def in_batches
      normalize

      files.each do |file|
        yield read_file(file)
      end
    end

    def files
      Dir.glob(File.join(root_dir, "*.{csv,parquet}"))
    end

    private

    def read_file(file)
      ext = Pathname.new(file).extname.gsub(/\./, "")
      case ext
      when "csv"
        filtered_args = filter_polars_args(Polars.method(:read_csv))
        df = Polars.read_csv(file, **filtered_args)
      when "parquet"
        filtered_args = filter_polars_args(Polars.method(:read_parquet))
        df = Polars.read_parquet(file, **filtered_args)
      end
      df
    end

    def all_parquet?
      files.all? { |f| f.match?(/\.parquet$/) }
    end

    def filter_polars_args(method)
      supported_params = method.parameters.map { |_, name| name }
      polars_args.select { |k, _| supported_params.include?(k) }
    end

    def convert_to_parquet
      return files if all_parquet?

      puts "Converting to Parquet..."

      Parallel.each(files, in_threads: 8) do |path|
        puts path
        df = read_file(path)
        df = cast(df)
        orig_path = path.dup
        ext = Pathname.new(path).extname.gsub(/\./, "")
        path = path.gsub(Regexp.new(ext), "parquet")
        df.write_parquet(path)
        FileUtils.rm(orig_path)
      end
    end

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

    def learn_schema
      puts "Normalizing schema..."
      combined_schema = {}

      files.each do |path|
        df = read_file(path)
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
