module EasyML
  module Data
    class DatasetManager
      class PartitionedWriter < Writer
        def can_partition?(df)
          @partitioned ||= begin
              primary_key.present? &&
                df.columns.include?(primary_key) &&
                numeric_primary_key?
            end
        end

        def min_key
          @min_key ||= df[primary_key].min
        end

        def max_key
          @max_key ||= df[primary_key].max
        end

        def batch_size
          @batch_size ||= feature.batch_size || 10_000
        end

        def numeric_primary_key?
          begin
            # We are intentionally not using to_i, so it will raise an error for keys like "A1"
            min_key = Integer(min_key) if min_key.is_a?(String)
            max_key = Integer(max_key) if max_key.is_a?(String)
            min_key.is_a?(Integer) && max_key.is_a?(Integer)
          rescue ArgumentError
            false
          end
        end

      end
    end
  end
end