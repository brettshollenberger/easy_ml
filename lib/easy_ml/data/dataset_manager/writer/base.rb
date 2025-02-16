module EasyML
  module Data
    class DatasetManager
      class Writer
        class Base
          attr_accessor :filenames, :root_dir, :options, :df

          def initialize(options)
            @root_dir = options.dig(:root_dir)
            @filenames = options.dig(:filenames)
            @options = options
            @df = options.dig(:df)
          end

          def wipe
            unlock!
            FileUtils.rm_rf(root_dir)
          end

          def store
            filename = File.join(root_dir, "main.parquet")

            # lock_file(filename) do |f|
            append(df, filename)
            # end
          end

          def unlock!
            list_keys.each { |key| unlock_file(key) }
          end

          private

          def reader
            EasyML::Data::DatasetManager.new(options)
          end

          def append(df, filename)
            if File.exist?(filename)
              existing_df = reader.query(filename)
              preserved_records = existing_df.filter(
                Polars.col(primary_key).is_in(df[primary_key]).is_not
              )
              if preserved_records.shape[1] != df.shape[1]
                wipe
              else
                df = Polars.concat([preserved_records, df], how: "vertical")
              end
            end
            safe_write(df, filename)
          end

          def lock_file(filename)
            Support::Lockable.with_lock(file_lock_key(filename), wait_timeout: 2, stale_timeout: 60) do |client|
              begin
                # add_key(file_lock_key(filename))
                yield client if block_given?
              ensure
                unlock_file(filename)
              end
            end
          end

          def file_lock_key(filename)
            "easy_ml:dataset_manager:writer:#{filename}:v5"
          end

          def unlock_file(filename)
            Support::Lockable.unlock!(file_lock_key(filename))
            # clear_key(file_lock_key(filename))
          end

          def files
            DatasetManager.new(options).files
          end

          def query(**kwargs, &block)
            DatasetManager.new(options).query(root_dir, **kwargs, &block)
          end

          def store_to_unique_file(subdir: nil)
            safe_write(df, unique_path(subdir: subdir))
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
            keys = list_keys
            Support::Lockable.with_lock(keys, wait_timeout: 2) do |suo|
              suo.client.del(keys)
            end
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

          def clear_key(key)
            keylist = unique_id_key(subdir: "keylist")

            Support::Lockable.with_lock(keylist, wait_timeout: 2) do |suo|
              suo.client.srem(keylist, key)
            end
          end

          def add_key(key)
            keylist = unique_id_key(subdir: "keylist")

            Support::Lockable.with_lock(keylist, wait_timeout: 2) do |suo|
              suo.client.sadd(keylist, key)
            end
          end

          def list_keys
            keylist = unique_id_key(subdir: "keylist")

            begin
              Support::Lockable.with_lock(keylist, wait_timeout: 2) do |suo|
                suo.client.smembers(keylist)
              end
            rescue => e
              []
            end
          end

          def key_exists?(key)
            keylist = unique_id_key(subdir: "keylist")
            Support::Lockable.with_lock(keylist, wait_timeout: 2) do |suo|
              suo.client.sismember(keylist, key)
            end
          end

          def unique_id(subdir: nil)
            key = unique_id_key(subdir: subdir)
            add_key(key)

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
