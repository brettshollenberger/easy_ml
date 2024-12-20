module EasyML
  class FeatureStore
    class << self
      def store(feature, df)
        primary_key = feature.primary_key&.first
        return store_without_partitioning(feature, df) unless primary_key

        min_key = df[primary_key].min
        max_key = df[primary_key].max
        batch_size = feature.batch_size || 10_000

        # Try to parse as integers if they're strings
        begin
          min_key = Integer(min_key) if min_key.is_a?(String)
          max_key = Integer(max_key) if max_key.is_a?(String)
        rescue ArgumentError
          return store_without_partitioning(feature, df)
        end

        # Only partition if we have integer keys where we can predict boundaries
        return store_without_partitioning(feature, df) unless min_key.is_a?(Integer) && max_key.is_a?(Integer)

        partitions = compute_partition_boundaries(min_key, max_key, batch_size)
        partitions.each do |partition_start|
          partition_end = partition_start + batch_size - 1
          partition_df = df.filter(
            (Polars.col(primary_key) >= partition_start) &
            (Polars.col(primary_key) <= partition_end)
          )

          next if partition_df.height == 0

          store_partition(feature, partition_df, primary_key, partition_start)
        end
      end

      def query(feature, filter: nil)
        if filter&.is_primary_key_filter?(feature.primary_key)
          query_partitions(feature, filter)
        else
          query_all_partitions(feature, filter)
        end
      end

      def list_partitions(feature)
        Dir.glob(File.join(feature_dir(feature), "feature*.parquet")).sort
      end

      def wipe(feature)
        FileUtils.rm_rf(feature_dir(feature))
      end

      private

      def store_without_partitioning(feature, df)
        path = feature_path(feature)
        FileUtils.mkdir_p(File.dirname(path))
        df.write_parquet(path)
      end

      def store_partition(feature, partition_df, primary_key, partition_start)
        path = partition_path(feature, partition_start)
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

      def query_partitions(feature, filter)
        primary_key_values = filter.extract_primary_key_values
        batch_size = feature.batch_size || 10_000

        partition_files = primary_key_values.map do |key|
          partition_start = (key / batch_size.to_f).floor * batch_size
          partition_path(feature, partition_start)
        end.uniq.select { |path| File.exist?(path) }

        return Polars::DataFrame.new if partition_files.empty?

        reader = EasyML::Data::PolarsReader.new
        reader.query(partition_files, filter: filter)
      end

      def query_all_partitions(feature, filter)
        reader = EasyML::Data::PolarsReader.new
        pattern = File.join(feature_dir(feature), "feature*.parquet")
        files = Dir.glob(pattern)

        return Polars::DataFrame.new if files.empty?

        reader.query(files, filter: filter)
      end

      def compute_partition_boundaries(min_key, max_key, batch_size)
        start_partition = (min_key / batch_size.to_f).floor * batch_size
        end_partition = (max_key / batch_size.to_f).floor * batch_size

        (start_partition..end_partition).step(batch_size).to_a
      end

      def feature_dir(feature)
        File.join(
          Rails.root,
          "easy_ml/datasets",
          feature.dataset.name.parameterize,
          "features",
          feature.name.parameterize,
          feature.version.to_s
        )
      end

      def feature_path(feature)
        File.join(feature_dir(feature), "feature.parquet")
      end

      def partition_path(feature, partition_start)
        File.join(feature_dir(feature), "feature#{partition_start}.parquet")
      end
    end
  end
end
