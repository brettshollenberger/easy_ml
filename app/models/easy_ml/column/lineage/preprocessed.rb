module EasyML
  class Column
    class Lineage
      class Preprocessed < Base
        def key
          :preprocessed
        end

        def description
          "Preprocessed using #{column.imputers.preprocessing_descriptions.join(", ")}"
        end

        def timestamp
          column.dataset.refreshed_at
        end

        def check
          column.preprocessing_steps.present?
        end
      end
    end
  end
end
