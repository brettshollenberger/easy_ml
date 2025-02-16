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

          def process_batches(&b)
            raise "When using batch_size, sort must match primary key (#{batch_key})" if sort.present? && batch_key != sort
            block = b || self.block

            sort = batch_key

            current_start = get_batch_start
            final_value = get_final_value

            while current_start < final_value
              filter = Polars.col(sort) >= current_start
              batch = query_files(filter: filter, limit: batch_size, lazy: true, sort: sort, descending: descending)
              block.yield(batch)
              current_start = File.new(input: input, lazy: true)
                                  .query
                                  .filter(filter)
                                  .sort(sort, reverse: descending)
                                  .limit(batch_size + 1)
                                  .sort(sort, reverse: !descending)
                                  .limit(1)
                                  .select(sort)
                                  .collect
                                  .to_a.first&.dig(sort) || final_value
            end
          end

          def query_files(overrides = {})
            query = options.deep_dup.merge!(overrides).except(:batch_size, :batch_start, :batch_key)
            File.new(query).query
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

          def get_sorted_batch_keys(descending, filter: nil)
            query = query_files(lazy: true)
            query = query.filter(filter) if filter
            query.sort(batch_key, reverse: descending).limit(1).select(batch_key).collect.to_a.last.dig(batch_key)
          end

          def batch_key
            return @batch_key if @batch_key

            lazy_df = lazy_frames([files.first]).first
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
