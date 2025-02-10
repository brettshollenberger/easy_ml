module EasyML
  class Column
    module Learners
      class Null < Base
        def full_dataset_statistics(df)
          []
        end

        def train_statistics(df)
          []
        end
      end
    end
  end
end
