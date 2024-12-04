module EasyML
  module Data
    class PolarsReader
      include GlueGun::DSL

      attribute :root_dir
      attribute :polars_args, :hash, default: {}
      attribute :refresh, :boolean, default: false
      attribute :num_rows, :integer
      attribute :schema

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

      def schema
        polars_args[:dtypes]
      end

      def data
        query
      end

      def query(files = nil, drop_cols: [], filter: nil, limit: nil, select: nil, unique: nil, sort: nil,
                descending: false)
        files ||= self.files
        PolarsReader.query(files, drop_cols: drop_cols, filter: filter, limit: limit,
                                  select: select, unique: unique, sort: sort, descending: descending)
      end

      def self.query(files, drop_cols: [], filter: nil, limit: nil, select: nil, unique: nil, sort: nil, descending: false)
        # Process all files together when no block is given
        files = files.select { |f| Pathname.new(f).extname == ".parquet" }
        return Polars::DataFrame.new if files.empty?

        lazy_frames = files.map { |file| Polars.scan_parquet(file) }
        combined_lazy_df = Polars.concat(lazy_frames)

        # Apply the predicate filter if given
        combined_lazy_df = combined_lazy_df.filter(filter) if filter
        # Apply select columns if provided
        combined_lazy_df = combined_lazy_df.select(select) if select.present?
        combined_lazy_df = combined_lazy_df.unique if unique

        # Apply drop columns
        drop_cols &= combined_lazy_df.columns
        combined_lazy_df = combined_lazy_df.drop(drop_cols) unless drop_cols.empty?

        # Apply sorting if provided
        combined_lazy_df = combined_lazy_df.sort(sort, reverse: descending) if sort

        # Collect the DataFrame (execute the lazy operations)
        combined_lazy_df = combined_lazy_df.limit(limit) if limit
        combined_lazy_df.collect
      end

      private

      def read_file(file)
        ext = Pathname.new(file).extname.gsub(/\./, "")
        case ext
        when "csv"
          filtered_args = filter_polars_args(Polars.method(:read_csv))
          filtered_args.merge!(infer_schema_length: 1_000_000, null_values: ["\\N", "\\\\N", "NULL"])
          df = Polars.read_csv(file, **filtered_args)
        when "parquet"
          filtered_args = filter_polars_args(Polars.method(:read_parquet))
          df = Polars.read_parquet(file, **filtered_args)
        end
        df
      end

      def any_parquet?
        files.any? { |f| f.match?(/\.parquet$/) }
      end

      def filter_polars_args(method)
        supported_params = method.parameters.map { |_, name| name }
        polars_args.select { |k, _| supported_params.include?(k) }
      end

      def csv_files
        Dir.glob(File.join(root_dir, "**/*.{csv}"))
      end

      def parquet_files
        Dir.glob(File.join(root_dir, "**/*.{parquet}"))
      end

      def convert_to_parquet
        return files if any_parquet?

        puts "Converting to Parquet..."

        csv_files.each do |path|
          puts path
          df = read_file(path)
          df = cast(df)
          path.dup
          filename = Pathname.new(path).basename
          ext = Pathname.new(path).extname.gsub(/\./, "")
          filename = filename.to_s.gsub(Regexp.new(ext), "parquet")
          path = File.join(root_dir, filename).to_s
          df.write_parquet(path)
        end
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

      def learn_dataset
        return schema if schema.present?

        puts "Normalizing schema..."
        self.num_rows = 0
        first_file = read_file(files.first)

        combined_schema = files.map.with_index do |path, _idx|
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

        self.schema = combined_schema
        polars_args[:dtypes] = combined_schema
      end
    end
  end
end
