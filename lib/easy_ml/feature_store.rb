module EasyML
  class FeatureStore < EasyML::Data::DatasetManager
    attr_reader :feature

    def initialize(feature)
      @feature = feature

      datasource_config = feature.dataset.datasource.configuration || {}

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

    def batch_size
      @batch_size ||= feature.batch_size || 10_000
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

    def s3_prefix
      File.join("datasets", feature_dir.split("datasets").last)
    end
  end
end
