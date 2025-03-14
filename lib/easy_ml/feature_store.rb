module EasyML
  class FeatureStore < EasyML::Data::DatasetManager
    attr_reader :feature, :dataset

    def initialize(feature)
      @feature = feature
      @dataset = feature&.dataset

      datasource_config = feature&.dataset&.datasource&.configuration
      if datasource_config
        options = {
          root_dir: feature_dir,
          filenames: "feature",
          append_only: false,
          primary_key: feature.primary_key&.first,
          partition_size: batch_size,
          s3_bucket: datasource_config.dig("s3_bucket") || EasyML::Configuration.s3_bucket,
          s3_prefix: s3_prefix,
          polars_args: datasource_config.dig("polars_args"),
        }.compact
        super(options)
      else
        super({ root_dir: "" })
      end
    end

    def synced?
      files.any?
    end

    def bump_version(original_version, version)
      compact
      cp(
        feature_dir.gsub(version, original_version),
        feature_dir,
      )
    end

    # Expose S3 information for testing and verification
    def s3_prefix
      EasyML::Configuration.dataset_s3_path(
        File.join(feature_dir.split("datasets").last, "compacted")
      )
    end

    def s3_key(filename = nil)
      filename ||= File.basename(files.first) if files.any?
      return nil unless filename
      File.join(s3_prefix, filename)
    end

    private

    def batch_size
      @batch_size ||= feature.batch_size || 10_000
    end

    def feature_dir
      File.join(
        dataset.dir,
        "features",
        feature&.name&.parameterize&.gsub("-", "_")
      )
    end
  end
end
