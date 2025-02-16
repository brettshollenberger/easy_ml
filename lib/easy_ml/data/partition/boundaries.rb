module EasyML
  module Data
    module Partition
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
              .floor
              .add(1)
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
          # @boundaries = @boundaries.with_columns(
          #   Polars.col(primary_key).is_between(Polars.col("partition_start"), Polars.col("partition_end")).select("partition")
          # )
        end

        def to_a
          sorted = boundaries.select(["partition", "partition_start", "partition_end"]).unique.sort("partition")
          is_lazy = sorted.is_a?(Polars::LazyFrame)
          array = (is_lazy ? sorted.collect.to_a : sorted.to_a).map(&:with_indifferent_access)
          # For the last partition, set the end to the total number of rows (so we read the last row with is_between queries)
          last_idx = array.size - 1
          array[last_idx]["partition_end"] = is_lazy ? df.select(Polars.col(primary_key)).max.collect.to_a.first.dig(primary_key) : df[primary_key].max
          array
        end
      end
    end
  end
end
