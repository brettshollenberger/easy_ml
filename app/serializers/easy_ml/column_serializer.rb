# == Schema Information
#
# Table name: easy_ml_columns
#
#  id                  :bigint           not null, primary key
#  dataset_id          :bigint           not null
#  name                :string           not null
#  description         :string
#  datatype            :string
#  polars_datatype     :string
#  preprocessing_steps :json
#  is_target           :boolean
#  hidden              :boolean          default(FALSE)
#  drop_if_null        :boolean          default(FALSE)
#  sample_values       :json
#  statistics          :json
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
module EasyML
  class ColumnSerializer
    include JSONAPI::Serializer

    attributes :id, :name, :description, :dataset_id, :datatype, :polars_datatype, :preprocessing_steps,
               :hidden, :drop_if_null, :sample_values, :statistics, :is_target
  end
end
