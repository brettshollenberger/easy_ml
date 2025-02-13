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

        def occurred_at
          column.dataset.refreshed_at
        end

        def check
          column.preprocessing_steps.present?
        end
      end
    end
  end
end
