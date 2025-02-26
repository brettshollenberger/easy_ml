module EasyML
  module Data
    class DatasetManager
      class Writer
        class AppendOnly < Base
          attr_accessor :primary_key

          def initialize(options)
            super
            @primary_key = options.dig(:primary_key)
            raise "primary_key required for append_only writer" if primary_key.nil?
            raise "filenames required: specify the prefix to uuse for unique new files" unless filenames.present?
          end

          def store
            @df = @df.unique(subset: [primary_key])
            return super if files.empty?

            # Get existing data lazily
            existing_keys = query(lazy: true)
              .select(primary_key)
              .collect[primary_key]
              .to_a

            # Convert input to lazy if it isn't already
            input_data = df.is_a?(Polars::LazyFrame) ? df : df.lazy

            # Filter out records that already exist
            new_records = input_data.filter(
              Polars.col(primary_key).is_in(existing_keys).not_
            )

            # If we have new records, store them
            if new_records.clone.select(Polars.length).collect[0, 0] > 0
              @df = new_records
              store_to_unique_file
            end
          end

          def compact
            files = self.files
            return if files.empty?

            clear_unique_id

            # Mv existing compacted parquet to a temp file, so it doesn't conflict with write,
            # but can still be queried
            compacted_file = File.join(root_dir, "compacted.parquet")
            if File.exist?(compacted_file)
              tmp_file = File.join(root_dir, "compacted.orig.parquet")
              FileUtils.mv(compacted_file, tmp_file)
            end
            files = self.files

            compacted_file.tap do |target_file|
              compacted_data = query(lazy: true).sort(primary_key)

              safe_write(compacted_data, target_file)
              FileUtils.rm(files)
              clear_unique_id
            end
          end
        end
      end
    end
  end
end
