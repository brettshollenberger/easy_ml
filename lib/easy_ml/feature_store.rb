module EasyML
  class FeatureStore < EasyML::Data::DatasetManager
    attr_reader :feature

    def initialize(feature)
      @feature = feature

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

    def bump_version(version)
      compact
      cp(
        feature_dir_for_version(version),
        feature_dir_for_version(version + 1),
      )
    end

    private

    def batch_size
      @batch_size ||= feature.batch_size || 10_000
    end

    def feature_dir_for_version(version)
      File.join(
        Rails.root,
        "easy_ml/datasets",
        feature&.dataset&.name&.parameterize&.gsub("-", "_"),
        "features",
        feature&.name&.parameterize&.gsub("-", "_"),
        version.to_s
      )
    end

    def feature_dir
      feature_dir_for_version(feature.version)
    end

    def s3_prefix
      File.join("datasets", feature_dir.split("datasets").last)
    end
  end
end
