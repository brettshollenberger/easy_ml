require "jsonapi/serializer"

module EasyML
  class ModelSerializer
    include JSONAPI::Serializer

    set_type :model # Optional type for JSON:API

    attributes :id, :name, :status, :model_type

    def datasets
      datasets.map do |dataset|
        DatasetSerializer.new(dataset).serializable_hash.dig(:data, :attributes)
      end
    end
  end
end
