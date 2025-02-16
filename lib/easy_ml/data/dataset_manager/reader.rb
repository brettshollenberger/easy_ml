module EasyML
  module Data
    class DatasetManager
      class Reader
        require_relative "reader/base"
        require_relative "reader/file"
        require_relative "reader/data_frame"

        ADAPTERS = [
          File,
          DataFrame,
        ]

        def self.query(input, **kwargs, &block)
          adapter(input).new(
            kwargs.merge!(input: input), &block
          ).query
        end

        def self.schema(input, **kwargs, &block)
          adapter(input).new(
            kwargs.merge!(input: input), &block
          ).schema
        end

        def self.files(dir)
          Dir.glob(::File.join(dir, "**/*.{parquet}"))
        end

        def self.sha
          files = sha.sort

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

        private

        def self.adapter(input)
          if input.is_a?(Polars::DataFrame) || input.is_a?(Polars::LazyFrame)
            DataFrame
          else
            File
          end
        end
      end
    end
  end
end
