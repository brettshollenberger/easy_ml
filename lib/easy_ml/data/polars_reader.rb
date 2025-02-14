module EasyML
  module Data
    class PolarsReader
      attr_accessor :root_dir, :polars_args, :refresh, :num_rows
      attr_reader :schema

      def initialize(options = {})
        @root_dir = options[:root_dir]
        @polars_args = options[:polars_args] || {}
        @refresh = options[:refresh] || false
        @num_rows = options[:num_rows]
        @schema = options[:schema]
      end

      def sha
        files = parquet_files.sort

        file_hashes = files.map do |file|
          meta = Polars.read_parquet_schema(file)
          row_count = Polars.scan_parquet(file).select(Polars.col("*").count).collect[0, 0]

          Digest::SHA256.hexdigest([
            meta.to_json,
            row_count.to_s,
          ].join("|"))
        end

        Digest::SHA256.hexdigest(file_hashes.join)
      end

      def schema=(value)
        @schema = value
        polars_args[:dtypes] = value
      end

      def normalize
        learn_dataset
        convert_to_parquet
        files
      end

      def clean
        FileUtils.rm(parquet_files) unless Rails.env.test?
      end

      def in_batches
        normalize

        files.each do |file|
          yield read_file(file)
        end
      end

      def all_files
        (parquet_files + csv_files)
      end

      def files
        if parquet_files.any? && !refresh
          parquet_files
        else
          csv_files
        end
      end

      def data
        query
      end

      def convert_to_parquet(columns = nil)
        return files if any_parquet? && columns.nil?

        puts "Converting to Parquet..."
        if columns.nil? || columns.all? { |c| c.datatype.nil? }
          learn_dataset
          columns = nil
        end
        csv_files.each do |path|
          df = read_file(path, columns)
          df = cast(df, columns)
          path.dup
          filename = Pathname.new(path).basename
          ext = Pathname.new(path).extname.gsub(/\./, "")
          filename = filename.to_s.gsub(Regexp.new(ext), "parquet")
          path = File.join(root_dir, filename).to_s
          df.write_parquet(path)
        end
      end

      def read_file(file, columns = nil)
        if columns
          dtypes = columns_to_dtypes(columns)
          polars_args[:dtypes] ||= {}
          polars_args[:dtypes].merge!(dtypes)
        end
        ext = Pathname.new(file).extname.gsub(/\./, "")
        date_cols = []
        case ext
        when "csv"
          filtered_args, date_cols = filter_polars_args(Polars.method(:read_csv))
          filtered_args.merge!(
            infer_schema_length: 1_000_000,
            null_values: ["\\N", "\\\\N", "NULL"],
          )
          df = Polars.read_csv(file, **filtered_args)
        when "parquet"
          filtered_args, date_cols = filter_polars_args(Polars.method(:read_parquet))
          df = Polars.read_parquet(file, **filtered_args)
        end
        date_cols.each do |col|
          df = EasyML::Data::DateConverter.maybe_convert_date(df, col)
        end
        df
      end

      def any_parquet?
        files.any? { |f| f.match?(/\.parquet$/) }
      end

      def filter_polars_args(method)
        supported_params = method.parameters.map { |_, name| name }
        filtered = polars_args.select { |k, _| supported_params.include?(k) }

        # Filter out any datetime columns, and use maybe_convert_date to convert later
        date_cols = (filtered[:dtypes] || {}).select { |k, v| v.class == Polars::Datetime }.keys
        filtered[:dtypes] = (filtered[:dtypes] || {}).reject { |k, v| v.class == Polars::Datetime }.compact.to_h
        filtered = filtered.select { |k, _| supported_params.include?(k) }
        return filtered, date_cols
      end

      def csv_files
        Dir.glob(File.join(root_dir, "**/*.{csv}"))
      end

      def parquet_files
        Dir.glob(File.join(root_dir, "**/*.{parquet}"))
      end

      def columns_to_dtypes(columns)
        columns.reduce({}) { |h, c| h[c.name] = c.polars_type; h }
      end

      def cast(df, columns = [])
        keep_cols = columns && columns.any? ? columns.map(&:name) : schema.keys
        lookup = columns && columns.any? ? columns_to_dtypes(columns) : schema
        cast_cols = keep_cols & df.columns
        df = df.with_columns(
          cast_cols.map do |column|
            dtype = lookup[column]
            df[column].cast(dtype).alias(column)
          end
        )
      end

      def existing_parquet_schema
        return nil if parquet_files.empty?

        file_path = parquet_files.first
        df = Polars.scan_parquet(file_path)
        df = df.limit(1)
        df.collect.schema
      end

      def learn_dataset
        return schema if schema.present?

        existing_schema = existing_parquet_schema
        schema = existing_schema || normalize_dataset

        self.schema = schema
        polars_args[:dtypes] = schema
      end

      def normalize_dataset
        puts "Normalizing schema..."
        self.num_rows = 0
        first_file = read_file(files.first)

        files.map.with_index do |path, _idx|
          df = read_file(path)
          self.num_rows += df.shape[0]
          df.schema
        end.inject({}) do |h, schema|
          h.tap do
            schema.each do |key, value|
              h[key] ||= []
              h[key] << value unless h[key].include?(value)
            end
          end
        end.inject({}) do |h, (k, v)|
          h.tap do
            values = v.map { |klass| klass.to_s.gsub(/Polars::/, "") }
            h[k] = if values.any? { |v| v.match?(/Float/) }
                Polars::Float64
              elsif values.any? { |v| v.match?(/Int/) }
                Polars::Int64
              else
                type = EasyML::Data::PolarsColumn.determine_type(first_file[k], true)
                raise "Cannot determine polars type for field #{k}" if type.nil?

                type
              end
          end
        end
      end
    end
  end
end
