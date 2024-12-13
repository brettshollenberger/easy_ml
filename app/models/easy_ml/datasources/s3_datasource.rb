module EasyML
  module Datasources
    class S3Datasource < BaseDatasource
      REGIONS = [
        { value: "us-east-1", label: "US East (N. Virginia)" },
        { value: "us-east-2", label: "US East (Ohio)" },
        { value: "us-west-1", label: "US West (N. California)" },
        { value: "us-west-2", label: "US West (Oregon)" },
      ].freeze

      def self.constants
        { S3_REGIONS: REGIONS }
      end

      validates :s3_bucket, :s3_access_key_id, :s3_secret_access_key, presence: true

      add_configuration_attributes :s3_bucket, :s3_prefix, :s3_region, :cache_for

      delegate :query, :data, :s3_access_key_id, :s3_secret_access_key, :before_sync, :after_sync, :clean,
               to: :synced_directory

      def in_batches(&block)
        synced_directory.in_batches(&block)
      end

      def all_files
        synced_directory.all_files
      end

      def files
        synced_directory.files
      end

      def last_updated_at
        synced_directory.last_updated_at
      end

      def needs_refresh?
        synced_directory.should_sync?
      end

      def refresh
        synced_directory.sync
      end

      def refresh!
        synced_directory.sync!
      end

      def files_to_sync
        synced_directory.files_to_sync
      end

      def download_file(file)
        synced_directory.download_file(file)
      end

      def exists?
        synced_directory.files_to_sync.any?
      end

      def error_not_exists
        "No files found at s3://#{File.join(s3_bucket, s3_prefix)}"
      end

      def s3_bucket
        datasource_config.dig("s3_bucket") || EasyML::Configuration.s3_bucket
      end

      def s3_prefix
        datasource_config.dig("s3_prefix")
      end

      def cache_for
        datasource_config.dig("cache_for") || 0
      end

      private

      def datasource_config
        @datasource_config ||= datasource.configuration || {}
      end

      def synced_directory
        @synced_directory ||= EasyML::Data::SyncedDirectory.new(
          root_dir: datasource.root_dir,
          s3_bucket: s3_bucket,
          s3_prefix: s3_prefix,
          s3_access_key_id: EasyML::Configuration.s3_access_key_id,
          s3_secret_access_key: EasyML::Configuration.s3_secret_access_key,
          polars_args: datasource_config.dig("polars_args") || {},
          cache_for: cache_for,
        )
      end
    end
  end
end
