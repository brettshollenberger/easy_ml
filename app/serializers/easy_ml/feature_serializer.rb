# == Schema Information
#
# Table name: easy_ml_transforms
#
#  id                 :bigint           not null, primary key
#  dataset_id         :bigint           not null
#  name               :string
#  feature_class    :string           not null
#  feature_method   :string           not null
#  feature_position :integer
#  applied_at         :datetime
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
require "jsonapi/serializer"

module EasyML
  class FeatureSerializer
    include JSONAPI::Serializer

    attributes :id, :feature_class, :feature_method, :feature_position, :name

    attribute :description do |feature|
      (EasyML::Features::Registry.find(feature.name) || {}).dig(:description)
    end
  end
end
