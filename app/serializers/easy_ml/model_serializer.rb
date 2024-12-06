require "jsonapi/serializer"

module EasyML
  class ModelSerializer
    include JSONAPI::Serializer

    set_type :model # Optional type for JSON:API

    attributes :id, :name, :description, :status

    def datasets
      datasets.map do |dataset|
        DatasetSerializer.new(dataset).serializable_hash.dig(:data, :attributes)
      end
    end
  end
end
