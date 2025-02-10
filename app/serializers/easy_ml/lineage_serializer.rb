require "jsonapi/serializer"

module EasyML
  class LineageSerializer
    include JSONAPI::Serializer

    attributes :id, :key, :description, :occurred_at
  end
end
