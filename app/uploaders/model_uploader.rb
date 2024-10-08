require "carrierwave"

module EasyML
  class ModelUploader < CarrierWave::Uploader::Base
    # Choose storage type
    if Rails.env.production?
      storage :fog
    else
      storage :file
    end

    def store_dir
      "easy_ml_models/#{model.version}"
    end

    def extension_allowlist
      %w[bin model json]
    end
  end
end
