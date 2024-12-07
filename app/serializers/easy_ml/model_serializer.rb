# == Schema Information
#
# Table name: easy_ml_models
#
#  id            :bigint           not null, primary key
#  name          :string           not null
#  model_type    :string
#  status        :string
#  dataset_id    :bigint
#  model_file_id :bigint
#  configuration :json
#  version       :string           not null
#  root_dir      :string
#  file          :json
#  sha           :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
require "jsonapi/serializer"

module EasyML
  class ModelSerializer
    include JSONAPI::Serializer

    set_type :model # Optional type for JSON:API

    attributes :id, :name, :status, :model_type, :status, :task, :objective, :hyperparameters, :metrics

    attribute :dataset do |model|
      DatasetSerializer.new(model.dataset).serializable_hash.dig(:data, :attributes)
    end

    attribute :retraining_job do |model|
      if model.retraining_job.present?
        {
          frequency: model.retraining_job.frequency,
          at: model.retraining_job.at,
          active: model.retraining_job.active,
          tuner_config: {
            n_trials: model.retraining_job.tuner_config&.dig("n_trials"),
            objective: model.retraining_job.tuner_config&.dig("objective"),
            config: model.retraining_job.tuner_config&.dig("config"),
          },
        }
      end
    end
  end
end
