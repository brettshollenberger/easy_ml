require_relative "./column_serializer"

# == Schema Information
#
# Table name: easy_ml_datasets
#
#  id              :bigint           not null, primary key
#  name            :string           not null
#  description     :string
#  dataset_type    :string
#  status          :string
#  version         :string
#  datasource_id   :bigint
#  root_dir        :string
#  configuration   :json
#  num_rows        :bigint
#  workflow_status :string
#  statistics      :json
#  schema          :json
#  refreshed_at    :datetime
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
module EasyML
  class DatasetSerializer
    include JSONAPI::Serializer

    attributes :id, :name, :description, :target, :num_rows, :status,
               :datasource_id, :preprocessing_steps, :workflow_status

    attribute :splitter do |dataset|
      dataset.splitter
    end

    attribute :columns do |dataset|
      dataset.columns.order(:id).map do |column|
        ColumnSerializer.new(column).serializable_hash.dig(:data, :attributes)
      end
    end

    attribute :sample_data do |dataset|
      if dataset.workflow_status.to_sym == :analyzing
        nil
      else
        dataset.data(limit: 10, all_columns: true)&.to_hashes
      end
    end

    attribute :updated_at do |dataset|
      dataset.datasource&.last_updated_at
    end

    attribute :transforms do |dataset|
      dataset.transforms.ordered.map do |transform|
        TransformSerializer.new(transform).serializable_hash.dig(:data, :attributes)
      end
    end

    attribute :needs_preprocess do |dataset|
      dataset.needs_preprocess
    end
  end
end
