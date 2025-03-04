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
            rows = query(lazy: true).collect
            return unless rows.shape[0] > 0

            FileUtils.rm(files)

            clear_unique_id
            File.join(root_dir, "compacted.parquet").tap do |target_file|
              safe_write(rows, target_file)
            end
            clear_unique_id
          end

          def cp(from,to)
            return if from.nil? || !Dir.exist?(from)

            FileUtils.mkdir_p(to)
            files_to_cp = Dir.glob(Pathname.new(from).join("**/*")).select { |f| File.file?(f) }

            files_to_cp.each do |file|
              target_file = file.gsub(from, to)
              FileUtils.mkdir_p(File.dirname(target_file))
              FileUtils.cp(file, target_file)
            end
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
            raise "df must be a Polars::DataFrame or Polars::LazyFrame" unless df.is_a?(Polars::DataFrame) || df.is_a?(Polars::LazyFrame)

            FileUtils.mkdir_p(File.dirname(path))
            if df.is_a?(Polars::LazyFrame)
              # Depending on the query plan, sometimes sink_parquet will throw an error...
              # in this case we have to collect first and fallback to write_parquet
              begin
                # Try the faster sink_parquet first
                df.sink_parquet(path)
              rescue Polars::InvalidOperationError => e
                # Fall back to collect().write_parquet()
                df.collect.write_parquet(path)
              end
            else
              # Already a materialized DataFrame
              df.write_parquet(path)
            end
            path
          ensure
            if Polars.scan_parquet(path).limit(1).schema.keys.empty?
              raise "Failed to store to #{path}"
            end
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
              suo.client.sadd?(keylist, key)
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
