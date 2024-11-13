# == Schema Information
#
# Table name: easy_ml_transforms
#
#  id               :bigint           not null, primary key
#  dataset_id       :bigint           not null
#  name             :string
#  transform_class  :string           not null
#  transform_method :string           not null
#  position         :integer
#  applied_at       :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
require "jsonapi/serializer"

module EasyML
  class TransformSerializer
    include JSONAPI::Serializer

    attributes :id, :transform_class, :transform_method, :position
  end
end
