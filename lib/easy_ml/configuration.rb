require "singleton"

module EasyML
  class Configuration
    include Singleton

    attr_accessor :s3_access_key_id, :s3_secret_access_key, :s3_bucket, :s3_region, :s3_prefix

    # Class method for configuration block
    class << self
      def configure
        yield instance
      end

      def s3_access_key_id
        instance.s3_access_key_id
      end

      def s3_secret_access_key
        instance.s3_secret_access_key
      end

      def s3_bucket
        instance.s3_bucket
      end

      def s3_region
        instance.s3_region
      end

      def s3_prefix
        instance.s3_prefix
      end
    end
  end
end
