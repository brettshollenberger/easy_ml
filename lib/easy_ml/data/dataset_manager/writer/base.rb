module EasyML
  module Data
    class DatasetManager
      class Writer
        class Base
          attr_accessor :filenames, :root_dir, :options, :append_only, :df

          def initialize(options)
            @root_dir = options.dig(:root_dir)
            @filenames = options.dig(:filenames)
            @append_only = options.dig(:append_only)
            @options = options
            @df = options.dig(:df)
            raise "filenames required: How should we name the new file?" if filenames.nil?
          end

          def wipe
            clear_unique_id
            FileUtils.rm_rf(root_dir)
          end

          def store
            store_to_unique_file
          end

          def compact
            files = self.files

            clear_unique_id
            File.join(root_dir, "compacted.parquet").tap do |target_file|
              query(lazy: true).sink_parquet(target_file)
              FileUtils.rm(files)
            end
            clear_unique_id
          end

          private

          def files
            DatasetManager.new(options).files
          end

          def query(**kwargs, &block)
            DatasetManager.new(options).query(root_dir, **kwargs, &block)
          end

          def store_to_unique_file(subdir = nil)
            begin
              safe_write(df, unique_path(subdir: subdir))
            rescue => e
              binding.pry
            end
          end

          def unique_path(subdir: nil)
            filename = "#{filenames}.#{unique_id(subdir: subdir)}.parquet"
            File.join(root_dir, subdir.to_s, filename)
          end

          def safe_write(df, path)
            FileUtils.mkdir_p(File.dirname(path))
            df.sink_parquet(path)
            path
          end

          def clear_unique_id(subdir: nil)
            key = unique_id_key(subdir: subdir)
            Support::Lockable.with_lock(key, wait_timeout: 2) do |suo|
              suo.client.del(key)
            end
          end

          def unique_id_key(subdir: nil)
            File.join("dataset_managers", root_dir, subdir.to_s, "sequence")
          end

          def unique_id(subdir: nil)
            key = unique_id_key(subdir: subdir)

            Support::Lockable.with_lock(key, wait_timeout: 2) do |suo|
              redis = suo.client

              seq = (redis.get(key) || "0").to_i
              redis.set(key, (seq + 1).to_s)
              seq + 1
            end
          end
        end
      end
    end
  end
end
