# == Schema Information
#
# Table name: easy_ml_datasets
#
#  id            :bigint           not null, primary key
#  name          :string           not null
#  description   :string
#  dataset_type  :string
#  status        :string
#  version       :string
#  datasource_id :bigint
#  root_dir      :string
#  configuration :json
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
module EasyML
  class DatasetSerializer
    include JSONAPI::Serializer

    attributes :name, :description, :target

    attribute :datasource_id do |dataset|
      dataset.datasource.id
    end

    attribute :preprocessing_steps do |dataset|
      dataset.preprocessing_steps
    end

    attribute :splitter do |dataset|
      dataset.splitter
    end
  end
end
