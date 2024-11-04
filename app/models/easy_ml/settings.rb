module EasyML
  class Settings < ActiveRecord::Base
    self.table_name = "easy_ml_settings"

    validates :storage, inclusion: { in: %w[file s3] }, if: -> { storage.present? }
  end
end
