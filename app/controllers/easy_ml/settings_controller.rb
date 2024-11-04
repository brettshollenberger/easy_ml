module EasyML
  class SettingsController < ApplicationController
    def index
      @settings = Settings.first_or_create
      render inertia: "pages/SettingsPage", props: {
        settings: { settings: @settings.as_json }
      }
    end

    def update
      @settings = Settings.first_or_create

      @settings.update(settings_params)
      EasyML::Configuration.configure do |config|
        config.storage = @settings.storage
        config.timezone = @settings.timezone
        config.s3_access_key_id = @settings.s3_access_key_id
        config.s3_secret_access_key = @settings.s3_secret_access_key
        config.s3_bucket = @settings.s3_bucket
        config.s3_region = @settings.s3_region
        config.s3_prefix = @settings.s3_prefix
      end
      render inertia: "pages/SettingsPage", props: {
        notice: "Settings were successfully updated.",
        settings: @settings.as_json
      }
    end

    private

    def settings_params
      params.require(:settings).permit(
        :storage,
        :timezone,
        :s3_access_key_id,
        :s3_secret_access_key,
        :s3_bucket,
        :s3_region,
        :s3_prefix
      )
    end
  end
end
