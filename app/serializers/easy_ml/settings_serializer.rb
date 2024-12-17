require "jsonapi/serializer"

module EasyML
  class SettingsSerializer
    include JSONAPI::Serializer

    attributes *EasyML::Settings.configuration_attributes
  end
end
