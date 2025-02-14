module EasyML
  module Data
    class DatasetManager
      class Reader
        require_relative "reader/base"
        require_relative "reader/file"
        require_relative "reader/data_frame"

        ADAPTERS = [
          File,
          DataFrame
        ]

        def self.query(input, **kwargs, &block)
          adapter(input).new(
            kwargs.merge!(input: input), &block
          ).query
        end

        def self.files(dir)
          Dir.glob(File.join(dir, "**/*.{parquet}"))
        end

      private
        def self.adapter(input)
          if input.is_a?(Polars::DataFrame)
            DataFrame
          else
            File
          end
        end

      end
    end
  end
end