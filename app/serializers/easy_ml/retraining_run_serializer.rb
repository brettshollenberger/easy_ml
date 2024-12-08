require "jsonapi/serializer"

module EasyML
  class RetrainingRunSerializer
    include JSONAPI::Serializer

    attributes :id,
               :should_promote,
               :metrics,
               :metric_value,
               :threshold,
               :threshold_direction,
               :status,
               :started_at,
               :completed_at,
               :error_message
  end
end
