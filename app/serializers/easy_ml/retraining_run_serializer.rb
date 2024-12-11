require "jsonapi/serializer"

module EasyML
  class RetrainingRunSerializer
    include JSONAPI::Serializer

    attributes :id,
               :deployable,
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

    attribute :stacktrace do |object|
      if object.status.to_s == "running"
        nil
      else
        last_event = object.events.order(id: :desc).limit(1).last
        last_event&.stacktrace if last_event&.status.to_s == "failed"
      end
    end
  end
end
