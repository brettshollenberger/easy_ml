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
              safe_write(
                query(lazy: true),
                target_file
              )
              FileUtils.rm(files)
            end
            clear_unique_id
          end

          def unlock!
            clear_all_keys
          end

          private

          def files
            DatasetManager.new(options).files
          end

          def query(**kwargs, &block)
            DatasetManager.new(options).query(root_dir, **kwargs, &block)
          end

          def store_to_unique_file(subdir: nil)
            safe_write(df, unique_path(subdir: subdir))
          end

          def acquire_lock(key, &block)
            Support::Lockable.with_lock("#{key}:lock", wait_timeout: 2, &block)
          end

          def unique_path(subdir: nil)
            filename = [filenames, unique_id(subdir: subdir), "parquet"].compact.join(".")

            File.join(root_dir, subdir.to_s, filename)
          end

          def safe_write(df, path)
            FileUtils.mkdir_p(File.dirname(path))
            df.is_a?(Polars::LazyFrame) ? df.sink_parquet(path) : df.write_parquet(path)
            path
          end

          def clear_all_keys
            list_keys.each { |key| unlock_file(key) }
          end

          def unlock_file(key)
            acquire_lock(key) do |suo|
              suo.client.del(key)
            end
          end

          def clear_unique_id(subdir: nil)
            key = unique_id_key(subdir: subdir)
            acquire_lock(key) do |suo|
              suo.client.del(key)
            end
          end

          def unique_id_key(subdir: nil)
            File.join("dataset_managers", root_dir, subdir.to_s, "sequence")
          end

          def add_key(key)
            keylist = unique_id_key(subdir: "keylist")

            acquire_lock(keylist) do |suo|
              suo.client.sadd(keylist, key)
            end
          end

          def list_keys
            keylist = unique_id_key(subdir: "keylist")

            acquire_lock(keylist) do |suo|
              if suo.client.type(keylist) == "set"
                suo.client.smembers(keylist)
              else
                suo.client.del(keylist)
                []
              end
            end
          end

          def key_exists?(key)
            keylist = unique_id_key(subdir: "keylist")

            acquire_lock(keylist) do |suo|
              suo.client.sismember(keylist, key)
            end
          end

          def unique_id(subdir: nil)
            key = unique_id_key(subdir: subdir)
            add_key(key)

            acquire_lock(key) do |suo|
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
