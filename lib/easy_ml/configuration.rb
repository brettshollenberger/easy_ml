require "singleton"
require_relative "../../app/models/easy_ml/settings"

module EasyML
  class Configuration
    include Singleton

    KEYS = %i[storage s3_access_key_id s3_secret_access_key s3_bucket s3_region s3_prefix timezone]

    KEYS.each do |key|
      define_method "#{key}=" do |value|
        db_settings.send("#{key}=", value)
      end

      define_method key do
        db_settings.send(key)
      end
    end

    class << self
      def configure
        yield instance
        instance.db_settings.save
      end

      KEYS.each do |key|
        define_method key do
          instance.send(key)
        end
      end

      private

      def db_settings
        instance.db_settings
      end
    end

    def db_settings
      @db_settings ||= EasyML::Settings.first_or_create
    end
  end
end
