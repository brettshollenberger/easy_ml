# == Schema Information
#
# Table name: easy_ml_settings
#
#  id            :bigint           not null, primary key
#  configuration :json
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
require_relative "concerns/configurable"

module EasyML
  class Settings < ActiveRecord::Base
    self.table_name = "easy_ml_settings"
    include EasyML::Concerns::Configurable

    add_configuration_attributes :storage,
      :s3_access_key_id, :s3_secret_access_key,
      :s3_bucket, :s3_region, :s3_prefix, :timezone,
      :wandb_api_key

    validates :storage, inclusion: { in: %w[file s3] }, if: -> { storage.present? }

    TIMEZONES = [
      { value: "America/New_York", label: "Eastern Time" },
      { value: "America/Chicago", label: "Central Time" },
      { value: "America/Denver", label: "Mountain Time" },
      { value: "America/Los_Angeles", label: "Pacific Time" },
    ]

    def self.constants
      {
        TIMEZONES: TIMEZONES,
      }
    end
  end
end
