require "jsonapi/serializer"

module EasyML
  class ModelSerializer
    include JSONAPI::Serializer

    set_type :model # Optional type for JSON:API

    attributes :id, :name, :description, :status
  end
end
