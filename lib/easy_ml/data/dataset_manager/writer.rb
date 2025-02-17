module EasyML
  module Data
    class DatasetManager
      class Writer
        require_relative "writer/base"
        require_relative "writer/partitioned"
        require_relative "writer/named"

        ADAPTERS = [
          Base,
          Partitioned,
          Named,
        ]

        attr_accessor :filenames, :root_dir, :partition,
                      :primary_key, :options

        def initialize(options)
          @root_dir = options.dig(:root_dir)
          @filenames = options.dig(:filenames)
          @partition = options.dig(:partition) || (options.dig(:partition_size).present? && options.dig(:primary_key).present?)
          @primary_key = options.dig(:primary_key)
          @named = options.dig(:named) || false
          @options = options
        end

        def unlock!
          adapter_class.new(options).unlock!
        end

        def store(df, *args)
          adapter_class.new(options.merge!(df: df)).store(*args)
        end

        def wipe
          adapter_class.new(options).wipe
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
          elsif named?
            Named
          else
            Base
          end
        end

        def named?
          @named
        end

        def partition?
          @partition
        end
      end
    end
  end
end
