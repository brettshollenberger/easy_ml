module EasyML
  class Column
    class Lineage
      class ComputedByFeature < Base
        def key
          :computed_by_feature
        end

        def description
          "Computed by #{column.computed_by}"
        end

        def occurred_at
          column.feature.fit_at || column.feature.applied_at
        end

        def check
          column.computed_by.present?
        end
      end
    end
  end
end
