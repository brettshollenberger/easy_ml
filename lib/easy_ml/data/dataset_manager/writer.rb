module EasyML
  module Data
    class DatasetManager
      class Writer
        require_relative "writer/base"
        require_relative "writer/partitioned"

        ADAPTERS = [
          Base,
          Partitioned,
        ]

        attr_accessor :filenames, :root_dir, :partitioned,
                      :append_only, :options

        def initialize(options)
          @root_dir = options.dig(:root_dir)
          @filenames = options.dig(:filenames)
          @partitioned = options.dig(:partitioned) || false
          @append_only = options.dig(:append_only)
          @options = options
        end

        def store(df)
          adapter.new(options).store(df)
        end

      private
        def adapter
          partitioned? ? PartitionedWriter : Writer
        end

        def partitioned?
          @partitioned
        end

      end
    end
  end
end