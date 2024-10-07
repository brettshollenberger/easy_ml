require "carrierwave"

module EasyML
  module Deployment
    class ModelUploader < CarrierWave::Uploader::Base
      # Choose storage type
      if Rails.env.production?
        storage :fog
      else
        storage :file
      end

      # Define the directory where uploaded files will be stored
      def store_dir
        "easy_ml_models/#{model.version}"
      end

      # Add any processing or versioning if needed
      # For example, to restrict file types:
      def extension_whitelist
        %w[bin model]
      end
    end
  end
end
