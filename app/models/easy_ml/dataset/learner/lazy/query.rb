module EasyML
  class Dataset
    class Learner
      class Lazy
        class Query < EasyML::Dataset::Learner::Query
          def adapter
            case dtype.to_sym
            when :float, :integer
              Lazy::Numeric
            when :string, :text
              Lazy::String
            when :categorical
              Lazy::Categorical
            when :datetime, :date
              Lazy::Datetime
            when :boolean
              Lazy::Boolean
            when :embedding
              Lazy::Embedding
            when :null
              Lazy::Null
            else
              raise "Don't know how to learn from dtype: #{dtype}"
            end
          end

          def execute(split)
            case split.to_sym
            when :train
              train_query
            when :data
              full_dataset_query
            end
          end

          private

          def full_dataset_query
            [num_rows, null_count].compact
          end

          def train_query
            [last_value, most_frequent_value].compact
          end

          def null_count
            Polars.col(column.name)
                  .cast(column.polars_datatype)
                  .null_count
                  .alias("#{column.name}__null_count")
          end

          def num_rows
            Polars.col(column.name)
                  .cast(column.polars_datatype)
                  .len
                  .alias("#{column.name}__num_rows")
          end

          def most_frequent_value
            Polars.col(column.name)
                  .cast(column.polars_datatype)
                  .filter(Polars.col(column.name).is_not_null)
                  .mode
                  .first
                  .alias("#{column.name}__most_frequent_value")
          end

          def last_value
            return unless dataset.date_column.present?

            Polars.col(column.name)
                  .cast(column.polars_datatype)
                  .sort_by(dataset.date_column.name, reverse: true, nulls_last: true)
                  .filter(Polars.col(column.name).is_not_null)
                  .first
                  .alias("#{column.name}__last_value")
          end
        end
      end
    end
  end
end
