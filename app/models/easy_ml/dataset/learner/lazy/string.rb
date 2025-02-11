module EasyML
  class Dataset
    class Learner
      class Lazy
        class String < Query
          def full_dataset_statistics(df)
            super.concat([
              unique_count(df),
            ])
          end

          def unique_count(df)
            Polars.col(column.name).cast(:str).n_unique.alias("#{column.name}__unique_count")
          end
        end
      end
    end
  end
end
