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

    attributes :id,
               :name,
               :model_type,
               :task,
               :objective,
               :weights_column,
               :metrics,
               :dataset_id,
               :status,
               :deployment_status,
               :configuration,
               :created_at,
               :updated_at,
               :last_run_at

    attribute :is_training do |object|
      object.training?
    end

    attribute :last_run do |object|
      RetrainingRunSerializer.new(object.last_run).serializable_hash.dig(:data, :attributes)
    end

    attribute :metrics_url do |object|
      object.last_run&.wandb_url
    end

    attribute :retraining_runs do |object, params|
      limit = params[:limit] || 20
      offset = params[:offset] || 0

      runs = object.retraining_runs
        .order(created_at: :desc)
        .offset(offset)
        .limit(limit)

      {
        runs: RetrainingRunSerializer.new(runs).serializable_hash[:data].map { |run| run[:attributes] },
        total_count: object.retraining_runs.count,
        limit: limit,
        offset: offset,
        next_offset: offset + limit,
        prev_offset: offset - limit,
      }
    end

    attribute :version do |object|
      object.formatted_version
    end

    attribute :formatted_model_type do |object|
      object.formatted_model_type
    end

    attribute :formatted_frequency do |object|
      object.retraining_job.present? ? object.retraining_job.formatted_frequency : nil
    end

    attribute :dataset do |object|
      DatasetSerializer.new(object.dataset).serializable_hash.dig(:data, :attributes)
    end

    attribute :retraining_job do |object|
      RetrainingJobSerializer.new(object.retraining_job).serializable_hash.dig(:data, :attributes)
    end
  end
end
