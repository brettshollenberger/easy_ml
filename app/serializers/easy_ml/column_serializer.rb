# == Schema Information
#
# Table name: easy_ml_columns
#
#  id                  :bigint           not null, primary key
#  dataset_id          :bigint           not null
#  name                :string           not null
#  datatype            :string
#  polars_datatype     :string
#  preprocessing_steps :json
#  hidden              :boolean          default(FALSE)
#  drop_if_null        :boolean          default(FALSE)
#  sample_values       :json
#  statistics          :json
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
module EasyML
  class ColumnSerializer
    attr_accessor :model

    def initialize(model)
      @model = model
    end

    def serializable_hash
      schema = model.schema
      model.columns
      stats = model.statistics

      {
        data: {
          attributes: schema.map do |col_name, col_type|
            {
              name: col_name,
              type: col_type,
              statistics: stats[col_name]
            }
          end
        }
      }
    end
  end
end
