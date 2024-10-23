module EasyML
  class Dataset < ActiveRecord::Base
    include GlueGun::Model
    service :dataset, EasyML::Data::Dataset

    validates :name, presence: true
    belongs_to :datasource,
               foreign_key: :datasource_id,
               class_name: "EasyML::Datasource"
  end
end
