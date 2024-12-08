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
               :error_message

    attribute :started_at do |run|
      run.started_at&.in_time_zone(EasyML::Configuration.timezone)
    end

    attribute :completed_at do |run|
      run.completed_at&.in_time_zone(EasyML::Configuration.timezone)
    end
  end
end
