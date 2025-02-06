module EasyML
  class Column
    class Lineage
      class Base
        attr_accessor :dataset, :column

        def initialize(column)
          @column = column
          @dataset = column.dataset
        end

        def as_json
          {
            key: key,
            description: description,
            timestamp: timestamp,
          }.with_indifferent_access
        end
      end
    end
  end
end
