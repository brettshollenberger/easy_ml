require "jsonapi/serializer"

module EasyML
  class RetrainingJobSerializer
    include JSONAPI::Serializer

    attributes :id,
               :active,
               :frequency,
               :formatted_frequency,
               :tuning_frequency,
               :at,
               :metric,
               :threshold,
               :tuner_config,
               :batch_mode,
               :batch_size,
               :batch_overlap
  end
end
