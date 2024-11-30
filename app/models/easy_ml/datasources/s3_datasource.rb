module EasyML
  module Datasources
    class S3Datasource < BaseDatasource
      REGIONS = [
        { value: "us-east-1", label: "US East (N. Virginia)" },
        { value: "us-east-2", label: "US East (Ohio)" },
        { value: "us-west-1", label: "US West (N. California)" },
        { value: "us-west-2", label: "US West (Oregon)" }
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
        return unless needs_refresh?

        datasource.syncing do
          synced_directory.sync
        end
      end

      def refresh!
        datasource.syncing do
          synced_directory.sync!
        end
      end

      def files_to_sync
        synced_directory.files_to_sync
      end

      def download_file(file)
        synced_directory.download_file(file)
      end

      private

      def synced_directory
        @synced_directory ||= EasyML::Data::SyncedDirectory.new(
          root_dir: datasource.root_dir,
          s3_bucket: datasource.configuration["s3_bucket"],
          s3_prefix: datasource.configuration["s3_prefix"],
          s3_access_key_id: EasyML::Configuration.s3_access_key_id,
          s3_secret_access_key: EasyML::Configuration.s3_secret_access_key,
          polars_args: datasource.configuration["polars_args"],
          cache_for: datasource.configuration["cache_for"]
        )
      end
    end
  end
end
