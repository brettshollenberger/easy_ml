module EasyML
  module Data
    class DatasetManager
      class Reader
        ADAPTERS = [
          File,
          DataFrame
        ]
        DEFAULTS = {
          drop_cols: [],
          filter: nil,
          limit: nil,
          select: nil,
          unique: nil,
          sort: nil,
          descending: false,
          batch_size: nil,
          batch_start: nil,
          batch_key: nil,
          lazy: false,
        }

        def self.query(input, **kwargs, &block)
          options = apply_defaults(kwargs).merge!(input: input)
          adapter(input).new(options, &block).query
        end

        def self.files(dir)
          Dir.glob(File.join(dir, "**/*.{parquet}"))
        end

      private
        def self.apply_defaults(**kwargs)
          options = kwargs.dup

          DEFAULTS.each do |k, default|
            unless options.key?(k)
              options[k] = default
            end
          end

          options
        end

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