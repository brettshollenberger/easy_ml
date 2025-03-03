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
#  is_target           :boolean
#  hidden              :boolean          default(FALSE)
#  drop_if_null        :boolean          default(FALSE)
#  preprocessing_steps :json
#  sample_values       :json
#  statistics          :json
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
module EasyML
  class ColumnSerializer
    class SmallSerializer
      include JSONAPI::Serializer
      attributes :id, :name
    end

    include JSONAPI::Serializer

    attributes :id, :name, :description, :dataset_id, :datatype, :polars_datatype, :preprocessing_steps,
               :hidden, :drop_if_null, :sample_values, :is_target,
               :is_computed, :computed_by

    attribute :required do |object|
      object.required?
    end

    attribute :statistics do |column|
      if column.is_computed?
        stats = column.statistics
        {
          raw: stats[:processed],
          processed: stats[:processed],
        }
      else
        column.statistics
      end
    end

    attribute :lineage do |column|
      column.lineages.map do |lineage|
        LineageSerializer.new(lineage).serializable_hash.dig(:data, :attributes)
      end
    end
  end
end
