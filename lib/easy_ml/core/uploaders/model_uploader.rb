require "carrierwave"
require "pry"

module EasyML
  module Core
    module Uploaders
      class ModelUploader < CarrierWave::Uploader::Base
        # Delay the storage type determination
        def storage_type
          if ENV["CARRIERWAVE_STORAGE"] == "fog" || Rails.env.production?
            :fog
          else
            :file
          end
        end

        def fog_public
          false
        end

        # Override the storage method at runtime
        def initialize(*)
          super
          self.class.storage storage_type
        end

        # Use class-specific fog directory configuration, defer its evaluation
        def fog_directory
          unless ENV.key?("EASY_ML_FOG_DIRECTORY")
            raise "Must set ENV['EASY_ML_FOG_DIRECTORY'] so we know where to save our models!"
          end

          ENV["EASY_ML_FOG_DIRECTORY"]
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
