module EasyML
  class Dataset
    class Learner
      class Lazy
        class Datetime < Query
          def full_dataset_query
            super.concat([
              unique_count,
            ])
          end

          def unique_count
            Polars.col(column.name).n_unique.alias("#{column.name}__unique_count")
          end
        end
      end
    end
  end
end
