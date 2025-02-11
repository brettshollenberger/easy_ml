module EasyML
  class Dataset
    class Learner
      class Lazy
        class Null < Query
          def full_dataset_query
            []
          end

          def train_query
            []
          end
        end
      end
    end
  end
end
