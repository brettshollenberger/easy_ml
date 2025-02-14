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
          adapter.store(df)
        end

        def wipe
          adapter.wipe
        end

        def inspect
          keys = %w(root_dir append_only partitioned primary_key)
          attrs = keys.map { |k| "#{k}=#{send(k)}" unless send(k).nil? }.compact
          "#<#{self.class.name} #{attrs.join(" ")}>"
        end

        private

        def adapter_class
          partitioned? ? PartitionedWriter : Base
        end

        def adapter
          @adapter ||= adapter_class.new(options)
        end

        def partitioned?
          @partitioned
        end
      end
    end
  end
end
