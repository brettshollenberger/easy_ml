# == Schema Information
#
# Table name: easy_ml_settings
#
#  id                   :bigint           not null, primary key
#  storage              :string
#  timezone             :string
#  s3_access_key_id     :string
#  s3_secret_access_key :string
#  s3_bucket            :string
#  s3_region            :string
#  s3_prefix            :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
module EasyML
  class SettingsController < ApplicationController
    def index
      @settings = Settings.first_or_create
      render inertia: "pages/SettingsPage", props: {
        settings: { settings: settings_to_json(@settings) },
      }
    end

    def update
      @settings = Settings.first_or_create

      @settings.update(settings_params)
      EasyML::Configuration.configure do |config|
        config.storage = @settings.storage
        config.timezone = @settings.timezone
        config.s3_bucket = @settings.s3_bucket
        config.s3_region = @settings.s3_region
        config.s3_prefix = @settings.s3_prefix
        config.wandb_api_key = @settings.wandb_api_key
      end
      flash.now[:notice] = "Settings saved."
      render inertia: "pages/SettingsPage", props: {
        settings: @settings.as_json,
      }
    end

    private

    def settings_params
      params.require(:settings).permit(
        :storage,
        :timezone,
        :s3_bucket,
        :s3_region,
        :s3_prefix,
        :wandb_api_key
      )
    end
  end
end
