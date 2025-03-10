module EasyML
  module Data
    class DatasetManager
      class Writer
        require_relative "writer/base"
        require_relative "writer/partitioned"
        require_relative "writer/append_only"
        require_relative "writer/named"
        require_relative "writer/delta"

        ADAPTERS = [
          Base,
          Partitioned,
          AppendOnly,
          Named,
          Delta,
        ]

        attr_accessor :filenames, :root_dir, :partition,
                      :primary_key, :options, :append_only, :named,
                      :use_delta

        def initialize(options)
          @root_dir = options.dig(:root_dir)
          @filenames = options.dig(:filenames)
          @partition = options.dig(:partition) || (options.dig(:partition_size).present? && options.dig(:primary_key).present?)
          @append_only = options.dig(:append_only)
          @primary_key = options.dig(:primary_key)
          @named = options.dig(:named) || false
          @use_delta = options.dig(:use_delta) || false
          @options = options
        end

        def unlock!
          adapter_class.new(options).unlock!
        end

        def cp(from, to)
          adapter_class.new(options).cp(from, to)
        end

        def store(df, *args)
          return df if df.is_a?(Polars::LazyFrame) ? df.schema.empty? : df.empty?

          adapter_class.new(options.merge!(df: df)).store(*args)
        end

        def merge(df, merge_config={})
          raise "Delta Lake must be enabled for merge operations" unless use_delta
          adapter_class.new(options.merge!(df: df)).merge(df, merge_config)
        end

        def upsert(df)
          raise "Delta Lake must be enabled for upsert operations" unless use_delta
          adapter_class.new(options.merge!(df: df)).upsert(df)
        end

        def vacuum(retention_hours: nil)
          raise "Delta Lake must be enabled for vacuum operations" unless use_delta
          adapter_class.new(options).vacuum(retention_hours: retention_hours)
        end

        def delete(predicate)
          raise "Delta Lake must be enabled for delete operations" unless use_delta
          adapter_class.new(options).delete(predicate)
        end

        def refresh_plan
          raise "Delta Lake must be enabled for refresh planning" unless use_delta
          adapter_class.new(options).refresh_plan
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
          if use_delta
            Delta
          elsif partition?
            Partitioned
          elsif append_only?
            AppendOnly
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

        def append_only?
          @append_only
        end
      end
    end
  end
end
