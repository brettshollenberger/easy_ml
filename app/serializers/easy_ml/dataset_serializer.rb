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
