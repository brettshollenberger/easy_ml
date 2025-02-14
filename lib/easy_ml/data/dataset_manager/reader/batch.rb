module EasyML
  module Data
    class DatasetManager
      class Reader
        class Batch < File
          def query
            return batch_enumerator unless block.present?
            return process_batches
          end

        private
          def batch_enumerator
            Enumerator.new do |yielder|
              process_batches do |batch|
                yielder << batch
              end
            end
          end

          def process_batches
            raise "When using batch_size, sort must match primary key (#{batch_key})" if sort.present? && batch_key != sort

            sort = batch_key
            
            is_first_batch = true
            batch_start = get_batch_start
            current_start = batch_start
            final_value = get_final_value

            while current_start < final_value
              filter = is_first_batch ? Polars.col(sort) >= current_start : Polars.col(sort) > current_start
              batch = query_files(filter: filter)
              yield batch
              current_start = query_files(filter: filter).sort(sort, reverse: !descending).limit(1).select(batch_key).collect[batch_key].to_a.last
              is_first_batch = false
            end
          end

          def query_files(overrides={})
            query = options.deep_dup.merge!(overrides)
            File.new(query).query
          end

          def get_batch(filter)
            File.new()
          end

          def get_batch_start
            if batch_start.present?
              batch_start
            else
              get_sorted_batch_keys(descending)
            end
          end

          def get_final_value
            get_sorted_batch_keys(!descending)
          end

          def get_sorted_batch_keys(descending)
            query_files(descending: descending).collect[batch_key].to_a.last
          end

          def batch_key
            return @batch_key if @batch_key

            lazy_df = to_lazy_frames([files.first]).first
            if select
              # Lazily filter only the selected columns
              lazy_df = lazy_df.select(select)

              # Lazily compute the unique count for each column and compare with total row count
              primary_keys = select.select do |col|
                lazy_df.select(col).unique.collect.height == lazy_df.collect.height
              end
            else
              primary_keys = lazy_df.collect.columns.select do |col|
                # Lazily count unique values and compare with the total row count
                lazy_df.select(col).unique.collect.height == lazy_df.collect.height
              end
            end

            if primary_keys.count > 1
              key = primary_keys.detect { |key| key.underscore.split("_").any? { |k| k.match?(/id/) } }
              if key
                primary_keys = [key]
              end
            end

            if primary_keys.count != 1
              raise "Unable to determine primary key for dataset"
            end

            @batch_key = primary_keys.first
          end
        end
      end
    end
  end
end
