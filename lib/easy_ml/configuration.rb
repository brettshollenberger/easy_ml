require "singleton"
require_relative "../../app/models/easy_ml/settings"

module EasyML
  class Configuration
    include Singleton

    TIMEZONES = [
      { value: "America/New_York", label: "Eastern Time" },
      { value: "America/Chicago", label: "Central Time" },
      { value: "America/Denver", label: "Mountain Time" },
      { value: "America/Los_Angeles", label: "Pacific Time" },
    ]
    KEYS = EasyML::Settings.configuration_attributes
    LABELER = {
      timezone: TIMEZONES,
    }

    KEYS.each do |key|
      define_method "#{key}=" do |value|
        db_settings.send("#{key}=", value)
      end

      define_method key do
        db_settings.send(key)
      end

      if LABELER.key?(key.to_sym)
        define_method "#{key}_label" do
          LABELER[key].find { |h| h[:value] == send(key) }[:label]
        end
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

        if LABELER.key?(key.to_sym)
          define_method "#{key}_label" do
            instance.send("#{key}_label")
          end
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

    def self.s3_path_for(type, name)
      File.join(instance.s3_prefix, type.to_s, name.to_s)
    end

    def self.model_s3_path(model_name)
      s3_path_for("models", model_name.parameterize.gsub("-", "_"))
    end

    def self.dataset_s3_path(relative_path)
      s3_path_for("datasets", relative_path)
    end
  end
end
