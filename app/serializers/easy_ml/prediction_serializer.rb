require "jsonapi/serializer"

module EasyML
  class PredictionSerializer
    include JSONAPI::Serializer

    attribute :prediction do |object|
      object.prediction_value.symbolize_keys.dig(:value)
    end

    attributes :id,
               :prediction_type,
               :raw_input,
               :normalized_input
  end
end
