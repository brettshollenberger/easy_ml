module EasyML
  class FeatureStore
    attr_reader :feature

    def initialize(feature)
      @feature = feature
    end

    def store(df)
      primary_key = feature.primary_key&.first
      return store_without_partitioning(df) unless df.columns.include?(primary_key)
      return store_without_partitioning(df) unless primary_key

      min_key = df[primary_key].min
      max_key = df[primary_key].max
      batch_size = feature.batch_size || 10_000

      # Try to parse as integers if they're strings
      begin
        min_key = Integer(min_key) if min_key.is_a?(String)
        max_key = Integer(max_key) if max_key.is_a?(String)
      rescue ArgumentError
        return store_without_partitioning(df)
      end

      # Only partition if we have integer keys where we can predict boundaries
      return store_without_partitioning(df) unless min_key.is_a?(Integer) && max_key.is_a?(Integer)

      partitions = compute_partition_boundaries(min_key, max_key, batch_size)
      partitions.each do |partition_start|
        partition_end = partition_start + batch_size - 1
        partition_df = df.filter(
          (Polars.col(primary_key) >= partition_start) &
          (Polars.col(primary_key) <= partition_end)
        )

        next if partition_df.height == 0

        store_partition(partition_df, primary_key, partition_start)
      end
    end

    def query(filter: nil)
      query_all_partitions(filter)
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
      synced_directory.download
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

    def store_without_partitioning(df)
      path = feature_path
      FileUtils.mkdir_p(File.dirname(path))
      df.write_parquet(path)
    end

    def store_partition(partition_df, primary_key, partition_start)
      path = partition_path(partition_start)
      FileUtils.mkdir_p(File.dirname(path))

      if File.exist?(path)
        reader = EasyML::Data::PolarsReader.new
        existing_df = reader.query([path])
        preserved_records = existing_df.filter(
          Polars.col(primary_key).is_in(partition_df[primary_key]).is_not
        )
        partition_df = Polars.concat([preserved_records, partition_df], how: "vertical")
      end

      partition_df.write_parquet(path)
    end

    def query_partitions(filter)
      primary_key_values = filter.extract_primary_key_values
      batch_size = feature.batch_size || 10_000

      partition_files = primary_key_values.map do |key|
        partition_start = (key / batch_size.to_f).floor * batch_size
        partition_path(partition_start)
      end.uniq.select { |path| File.exist?(path) }

      return Polars::DataFrame.new if partition_files.empty?

      reader = EasyML::Data::PolarsReader.new
      reader.query(partition_files, filter: filter)
    end

    def query_all_partitions(filter)
      reader = EasyML::Data::PolarsReader.new
      pattern = File.join(feature_dir, "feature*.parquet")
      files = Dir.glob(pattern)

      return Polars::DataFrame.new if files.empty?

      reader.query(files, filter: filter)
    end

    def compute_partition_boundaries(min_key, max_key, batch_size)
      start_partition = (min_key / batch_size.to_f).floor * batch_size
      end_partition = (max_key / batch_size.to_f).floor * batch_size
      (start_partition..end_partition).step(batch_size).to_a
    end

    def feature_dir_for_version(version)
      File.join(
        Rails.root,
        "easy_ml/datasets",
        feature.dataset.name.parameterize,
        "features",
        feature.name.parameterize,
        version.to_s
      )
    end

    def feature_dir
      feature_dir_for_version(feature.version)
    end

    def feature_path
      File.join(feature_dir, "feature.parquet")
    end

    def partition_path(partition_start)
      File.join(feature_dir, "feature#{partition_start}.parquet")
    end

    def s3_prefix
      File.join("datasets", feature_dir.split("datasets").last)
    end

    def synced_directory
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
  end
end
