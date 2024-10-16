require "carrierwave"

module EasyML
  module Core
    module Uploaders
      class ModelUploader < CarrierWave::Uploader::Base
        # Choose storage type
        if Rails.env.production?
          storage :fog
        else
          storage :file
        end

        def store_dir
          "easy_ml_models/#{model.name}"
        end

        def extension_allowlist
          %w[bin model json]
        end
      end
    end
  end
end
