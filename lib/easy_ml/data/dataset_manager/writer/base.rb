module EasyML
  module Data
    class DatasetManager
      class Writer
        class Base
          attr_accessor :filenames, :root_dir
          def initialize(options)
            @root_dir = options.dig(:root_dir)
            @filenames = options.dig(:filenames)
            @append_only = options.dig(:append_only)
          end

          def store(df)
            store_to_unique_file(df)
          end

        private
          def store_to_unique_file(df)
            safe_write(df, unique_path)
          end

          def unique_path(subdir: nil)
            filename = "#{filenames}.#{unique_id(subdir)}.parquet"
            File.join(feature_dir, subdir, filename)
          end

          def safe_write(df, path)
            FileUtils.mkdir_p(File.dirname(path))
            df.sink_parquet(path)
            path
          end

          def clear_unique_id(subdir: nil)
            key = unique_id_key(subdir)
            Support::Lockable.with_lock(key, wait_timeout: 2) do |suo|
              suo.client.del(key)
            end
          end

          def unique_id_key(subdir: nil)
            File.join("dataset_manager", root_dir, subdir, "sequence")
          end

          def unique_id(subdir: nil)
            key = unique_id_key(subdir)

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