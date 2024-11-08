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
      dataset.sample&.to_hashes
    end

    attribute :updated_at do |dataset|
      dataset.datasource&.last_updated_at
    end
  end
end
