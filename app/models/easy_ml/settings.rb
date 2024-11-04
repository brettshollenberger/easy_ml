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
  class Settings < ActiveRecord::Base
    self.table_name = "easy_ml_settings"

    validates :storage, inclusion: { in: %w[file s3] }, if: -> { storage.present? }

    TIMEZONES = [
      { value: "America/New_York", label: "Eastern Time" },
      { value: "America/Chicago", label: "Central Time" },
      { value: "America/Denver", label: "Mountain Time" },
      { value: "America/Los_Angeles", label: "Pacific Time" }
    ]

    def self.constants
      {
        TIMEZONES: TIMEZONES
      }
    end
  end
end
