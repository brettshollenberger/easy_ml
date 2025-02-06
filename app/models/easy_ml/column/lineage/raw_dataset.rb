module EasyML
  class Column
    class Lineage
      class RawDataset < Base
        def key
          :raw_dataset
        end

        def description
          "Present in raw dataset"
        end

        def timestamp
          column.dataset.datasource.refreshed_at
        end

        def check
          column.in_raw_dataset?
        end
      end
    end
  end
end
