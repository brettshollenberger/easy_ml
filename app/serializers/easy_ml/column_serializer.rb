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
