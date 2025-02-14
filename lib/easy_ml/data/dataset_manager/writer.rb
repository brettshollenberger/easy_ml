module EasyML
  module Data
    class DatasetManager
      class Writer
        require_relative "writer/base"
        require_relative "writer/partitioned"
        require_relative "writer/append_only"

        ADAPTERS = [
          Base,
          Partitioned,
          AppendOnly,
        ]

        attr_accessor :filenames, :root_dir, :partition,
                      :append_only, :primary_key, :options

        def initialize(options)
          @root_dir = options.dig(:root_dir)
          @filenames = options.dig(:filenames)
          @partition = options.dig(:partition) || false
          @append_only = options.dig(:append_only)
          @primary_key = options.dig(:primary_key)
          @options = options
        end

        def store(df)
          adapter_class.new(options.merge!(df: df)).store
        end

        def wipe
          adapter_class.new(options).wipe
        end

        def compact
          adapter_class.new(options).compact
        end

        def inspect
          keys = %w(root_dir append_only partition primary_key)
          attrs = keys.map { |k| "#{k}=#{send(k)}" unless send(k).nil? }.compact
          "#<#{self.class.name} #{attrs.join(" ")}>"
        end

        private

        def adapter_class
          if partition?
            Partitioned
          elsif append_only?
            AppendOnly
          else
            Base
          end
        end

        def partition?
          @partition
        end

        def append_only?
          @append_only
        end
      end
    end
  end
end
