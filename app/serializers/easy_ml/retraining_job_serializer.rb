require "jsonapi/serializer"

module EasyML
  class RetrainingJobSerializer
    include JSONAPI::Serializer

    set_type :retraining_job # Optional type for JSON:API

    attributes :id, :frequency, :at, :active, :tuner_config, :metric, :threshold, :direction, :last_run_at, :tuning_frequency
  end
end
