require "singleton"
require_relative "../../app/models/easy_ml/settings"

module EasyML
  class Configuration
    include Singleton

    class << self
      def configure
        yield instance
      end

      def storage
        instance&.storage || "s3"
      end

      def s3_access_key_id
        db_settings&.s3_access_key_id
      end

      def s3_secret_access_key
        db_settings&.s3_secret_access_key
      end

      def s3_bucket
        db_settings&.s3_bucket
      end

      def s3_region
        db_settings&.s3_region
      end

      def s3_prefix
        db_settings&.s3_prefix
      end

      def timezone
        db_settings&.timezone
      end

      private

      def db_settings
        instance.db_settings ||= EasyML::Settings.first_or_create
      end
    end

    # Keep instance attributes for backwards compatibility during configuration
    attr_accessor :storage, :s3_access_key_id, :s3_secret_access_key,
                  :s3_bucket, :s3_region, :s3_prefix, :db_settings, :timezone
  end
end
