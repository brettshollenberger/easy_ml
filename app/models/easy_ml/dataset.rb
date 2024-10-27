# == Schema Information
#
# Table name: easy_ml_datasets
#
#  id            :bigint           not null, primary key
#  name          :string           not null
#  dataset_type  :string
#  status        :string
#  version       :string
#  datasource_id :bigint
#  root_dir      :string
#  configuration :json
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
require_relative "concerns/statuses"
module EasyML
  class Dataset < ActiveRecord::Base
    include EasyML::Concerns::Statuses

    self.filter_attributes += [:configuration]

    include GlueGun::Model
    service :dataset, EasyML::Data::Dataset

    validates :name, presence: true
    belongs_to :datasource,
               foreign_key: :datasource_id,
               class_name: "EasyML::Datasource"

    has_many :models, class_name: "EasyML::Model"

    # Maybe copy attrs over from training to prod when marking is_live, so we keep 1 for training and one for live?
    #
    # def fit
    #   raise "Cannot train live dataset!" if is_live
    # end
  end
end
