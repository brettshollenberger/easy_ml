require "jsonapi/serializer"

module EasyML
  class PredictionSerializer
    include JSONAPI::Serializer

    attribute :prediction do |object|
      case object.prediction_value
      when Hash
        object.prediction_value.symbolize_keys.dig(:value)
      when Numeric
        object.prediction_value
      when Array
        object.prediction_value
      end
    end

    attributes :id,
               :prediction_type,
               :raw_input,
               :normalized_input,
               :model_history_id
  end
end
