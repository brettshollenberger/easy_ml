module EasyML
  module Data
    class DatasetManager
      class Writer
        class Partitioned < Base
          class Boundaries
            attr_reader :df, :primary_key, :partition_size

            def initialize(df, primary_key, partition_size)
              @df = df
              @primary_key = primary_key
              @partition_size = partition_size
            end

            def inspect
              "#<#{self.class.name.split("::").last} partition_size=#{partition_size} primary_key=#{primary_key}>"
            end

            def boundaries
              return @boundaries if @boundaries

              @boundaries = df.with_columns(
                Polars.col(primary_key)
                  .truediv(partition_size)
                  .ceil
                  .cast(Polars::Int64)
                  .alias("partition")
              )
              @boundaries = @boundaries.with_columns(
                Polars.col("partition")
                      .sub(1)
                      .mul(partition_size)
                      .cast(Polars::Int64)
                      .alias("partition_start"),
                Polars.col("partition")
                      .mul(partition_size)
                      .sub(1)
                      .cast(Polars::Int64)
                      .alias("partition_end")
              )
            end

            def to_a
              sorted = boundaries.select(["partition", "partition_start", "partition_end"]).unique.sort("partition")
              (sorted.is_a?(Polars::LazyFrame) ? sorted.collect.to_a : sorted.to_a).map(&:with_indifferent_access)
            end
          end
        end
      end
    end
  end
end
