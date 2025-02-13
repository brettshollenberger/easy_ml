module EasyML
  class Dataset
    class Learner
      class Eager
        class Query < EasyML::Dataset::Learner::Query
          def execute(split, df)
            case split.to_sym
            when :train
              train_query(df)
            when :data
              full_dataset_query(df)
            end
          end

          def train_query(df)
            {}
          end

          def full_dataset_query(df)
            {}
          end

          def adapter
            case (raw_dtype&.to_sym || dtype.to_sym)
            when :categorical
              Eager::Categorical
            when :boolean
              Eager::Boolean
            else
              nil
            end
          end
        end
      end
    end
  end
end
