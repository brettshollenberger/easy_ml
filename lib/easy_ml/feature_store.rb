module EasyML
  class FeatureStore
    attr_reader :feature

    def initialize(feature)
      @feature = feature
    end

    def store(df)
      if partitioned?
        store_each_partition(df)
      else
        store_without_partitioning(df)
      end
    end

    def merge
      if partitioned?
        merge_partitions
      else
        merge_nonpartitioned_files
      end
    end

    def query(**kwargs)
      query_all_partitions(**kwargs)
    end

    def empty?
      list_partitions.empty?
    end

    def list_partitions
      Dir.glob(File.join(feature_dir, "feature*.parquet")).sort
    end

    def wipe
      FileUtils.rm_rf(feature_dir)
    end

    def upload_remote_files
      synced_directory.upload
    end

    def download
      synced_directory&.download
    end

    def cp(old_version, new_version)
      old_dir = feature_dir_for_version(old_version)
      new_dir = feature_dir_for_version(new_version)

      return if old_dir.nil? || !Dir.exist?(old_dir)

      FileUtils.mkdir_p(new_dir)
      files_to_cp = Dir.glob(Pathname.new(old_dir).join("**/*")).select { |f| File.file?(f) }

      files_to_cp.each do |file|
        target_file = file.gsub(old_version.to_s, new_version.to_s)
        FileUtils.mkdir_p(File.dirname(target_file))
        FileUtils.cp(file, target_file)
      end
    end

    private

    def store_each_partition(df)
      partition_boundaries.each do |partition_start|
        partition_end = partition_start + batch_size - 1
        partition_df = df.filter(
          (Polars.col(primary_key) >= partition_start) &
          (Polars.col(primary_key) <= partition_end)
        )

        next if partition_df.height == 0

        store_to_unique_file(partition_df, partition_start: partition_start)
      end
    end

    def store_without_partitioning(df)
      store_to_unique_file(df)
    end

    def partition_dir(partition_start)
      File.join(feature_dir, partition_start)
    end

    def feature_path(subdir: nil)
      filename = "feature.#{unique_id(subdir)}.parquet"
      File.join(feature_dir, subdir, filename)
    end

    def store_to_unique_file(df, partition_start: nil)
      path = feature_path(subdir: partition_start)

      FileUtils.mkdir_p(File.dirname(path))
      df.sink_parquet(path)
      path
    end

    def query_partition(partition_start, **kwargs)
      EasyML::Data::Polars::Reader.new.query(
        [partition_dir(partition_start)],
        **kwargs,
      )
    end

    def merge_partition_files(partition_start)
      pattern = File.join(feature_dir, "feature#{partition_start}_*.parquet")
      files = Dir.glob(pattern).sort

      return if files.empty?

      reader = EasyML::Data::Polars::Reader.new
      merged_df = reader.query(files)

      # If we have a primary key, deduplicate based on it
      if (primary_key = feature.primary_key&.first)
        merged_df = merged_df.unique(subset: [primary_key], keep: "last")
      end

      target_path = partition_path(partition_start)
      lock_partition(partition_start) do
        FileUtils.mkdir_p(File.dirname(target_path))
        merged_df.sink_parquet(target_path)

        # Clean up individual files after successful merge
        files.each { |f| FileUtils.rm(f) }
      end
    end

    def merge_nonpartitioned_files
      pattern = File.join(feature_dir, "feature_*.parquet")
      files = Dir.glob(pattern).sort

      return if files.empty?

      reader = EasyML::Data::Polars::Reader.new
      merged_df = reader.query(files)

      # If we have a primary key, deduplicate based on it
      if (primary_key = feature.primary_key&.first)
        merged_df = merged_df.unique(subset: [primary_key], keep: "last")
      end

      lock_file do
        FileUtils.mkdir_p(File.dirname(feature_path))
        merged_df.sink_parquet(feature_path)

        # Clean up individual files after successful merge
        files.each { |f| FileUtils.rm(f) }
      end
    end

    def primary_key
      @primary_key ||= feature.primary_key&.first
    end

    def partitioned?
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

    def cleanup(type: :partitions)
      case type
      when :partitions
        list_partitions.each do |partition|
          FileUtils.rm(partition)
        end
      when :no_partitions
        FileUtils.rm_rf(feature_path)
      when :all
        wipe
      end
    end

    def query_all_partitions(**kwargs)
      reader = EasyML::Data::Polars::Reader.new
      pattern = File.join(feature_dir, "feature*.parquet")
      files = Dir.glob(pattern)

      return Polars::DataFrame.new if files.empty?

      reader.query(files, **kwargs)
    end

    def partition_boundaries
      start_partition = (min_key / batch_size.to_f).floor * batch_size
      end_partition = (max_key / batch_size.to_f).floor * batch_size
      (start_partition..end_partition).step(batch_size).to_a
    end

    def feature_dir_for_version(version)
      File.join(
        Rails.root,
        "easy_ml/datasets",
        feature.dataset.name.parameterize.gsub("-", "_"),
        "features",
        feature.name.parameterize.gsub("-", "_"),
        version.to_s
      )
    end

    def feature_dir
      feature_dir_for_version(feature.version)
    end

    def partition_path(partition_start)
      File.join(feature_dir, "feature#{partition_start}.parquet")
    end

    def s3_prefix
      File.join("datasets", feature_dir.split("datasets").last)
    end

    def synced_directory
      return unless feature.dataset&.datasource.present?

      datasource_config = feature.dataset.datasource.configuration || {}
      @synced_dir ||= EasyML::Data::SyncedDirectory.new(
        root_dir: feature_dir,
        s3_bucket: datasource_config.dig("s3_bucket") || EasyML::Configuration.s3_bucket,
        s3_prefix: s3_prefix,
        s3_access_key_id: EasyML::Configuration.s3_access_key_id,
        s3_secret_access_key: EasyML::Configuration.s3_secret_access_key,
        polars_args: datasource_config.dig("polars_args"),
        cache_for: 0,
      )
    end

    def clear_unique_id(partition_start = nil)
      key = unique_id_key(partition_start)
      Support::Lockable.with_lock(key, wait_timeout: 2) do |suo|
        suo.client.del(key)
      end
    end

    def unique_id_key(partition_start = nil)
      File.join("feature_store", feature.id.to_s, partition_start.to_s, "sequence")
    end

    def unique_id(partition_start = nil)
      key = unique_id_key(partition_start)

      Support::Lockable.with_lock(key, wait_timeout: 2) do |suo|
        redis = suo.client

        seq = (redis.get(key) || "0").to_i
        redis.set(key, (seq + 1).to_s)
        seq + 1
      end
    end

    def lock_partition(partition_start)
      Support::Lockable.with_lock(partition_lock_key(partition_start), wait_timeout: 2, stale_timeout: 60) do |client|
        begin
          yield client if block_given?
        ensure
          unlock_partition(partition_start)
        end
      end
    end

    def lock_file
      Support::Lockable.with_lock(file_lock_key, wait_timeout: 2, stale_timeout: 60) do |client|
        begin
          yield client if block_given?
        ensure
          unlock_file
        end
      end
    end

    def unlock_partition(partition_start)
      Support::Lockable.unlock!(partition_lock_key(partition_start))
    end

    def unlock_file
      Support::Lockable.unlock!(file_lock_key)
    end

    def unlock_all_partitions
      list_partitions.each do |partition_path|
        partition_start = partition_path.match(/feature(\d+)\.parquet/)[1].to_i
        unlock_partition(partition_start)
      end
    end

    def partition_lock_key(partition_start)
      "feature_store:#{feature.id}.partition.#{partition_start}"
    end

    def file_lock_key
      "feature_store:#{feature.id}.file"
    end
  end
end
