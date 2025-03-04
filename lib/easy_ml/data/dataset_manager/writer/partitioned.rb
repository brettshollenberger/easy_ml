module EasyML
  module Data
    class DatasetManager
      class Writer
        class Partitioned < Base
          require_relative "partitioned/partition_reasons"

          attr_accessor :partition_size, :partition, :primary_key, :df

          def initialize(options)
            super
            @partition_size = options.dig(:partition_size)
            @partition = options.dig(:partition)
            @primary_key = options.dig(:primary_key)

            raise "filenames required: specify the prefix to use for unique new files" unless filenames.present?
          end

          def wipe
            super
            clear_all_keys
          end

          def store
            unless can_partition?
              puts cannot_partition_reasons.explain
              return Base.new(options).store
            end

            store_each_partition
          end

          def compact
            return if compacted?

            @df = query(lazy: true)

            clear_unique_id(subdir: "compacted")
            compact_each_partition.tap do
              clear_unique_id
            end
            uncompacted_folders.each do |folder|
              FileUtils.rm_rf(File.join(root_dir, folder))
            end
          end

          private

          def compacted?
            uncompacted_folders.empty?
          end

          def uncompacted_folders
            folders - ["compacted"]
          end

          def folders
            Dir.glob(File.join(root_dir, "**/*")).select { |f| File.directory?(f) }.map { |f| f.split("/").last }
          end

          # def partitions
          #   Dir.glob(File.join(root_dir, "**/*")).map { |f| f.split("/").last }
          # end

          def compact_each_partition
            with_each_partition do |partition_df, _|
              safe_write(
                partition_df.sort(Polars.col(primary_key)),
                unique_path(subdir: "compacted")
              )
            end
          end

          def with_each_partition(&block)
            partition_boundaries.map do |partition|
              partition_start = partition[:partition_start]
              partition_end = partition[:partition_end]
              partition_df = df.filter(Polars.col(primary_key).is_between(partition_start, partition_end))
              num_rows = lazy? ? partition_df.select(Polars.length).collect[0, 0] : partition_df.shape[0]

              next if num_rows == 0
              yield partition_df, partition
            end
          end

          def store_each_partition
            with_each_partition do |partition_df, partition|
              safe_write(
                partition_df,
                unique_path(subdir: partition[:partition])
              )
            end
          end

          def partition_boundaries
            EasyML::Data::Partition::Boundaries.new(df, primary_key, partition_size).to_a
          end

          def cannot_partition_reasons
            @cannot_partition_reasons ||= PartitionReasons.new(self)
          end

          def can_partition?
            @partitioned ||= cannot_partition_reasons.none?
          end

          def lazy?
            df.is_a?(Polars::LazyFrame)
          end

          def cast_primary_key
            case dtype_primary_key
            when Polars::Categorical
              Polars.col(primary_key).cast(Polars::String)
            else
              Polars.col(primary_key)
            end
          end

          def dtype_primary_key
            @dtype_primary_key ||= schema[primary_key]
          end

          def schema
            @schema ||= df.schema
          end

          def min_key
            return @min_key if @min_key

            if lazy?
              @min_key = df.select(cast_primary_key).min.collect.to_a[0].dig(primary_key)
            else
              @min_key = df[primary_key].min
            end
          end

          def max_key
            return @max_key if @max_key

            if lazy?
              @max_key = df.select(cast_primary_key).max.collect.to_a[0].dig(primary_key)
            else
              @max_key = df[primary_key].max
            end
          end

          def numeric_primary_key?
            begin
              # We are intentionally not using to_i, so it will raise an error for keys like "A1"
              min = min_key.is_a?(String) ? Integer(min_key) : min_key
              max = max_key.is_a?(String) ? Integer(max_key) : max_key
              min.is_a?(Integer) && max.is_a?(Integer)
            rescue ArgumentError
              false
            end
          end
        end
      end
    end
  end
end
