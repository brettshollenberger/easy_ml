module EasyML
  class Dataset
    class Learner
      class Eager < Base
        def learn
          types.reduce({}) do |h, type|
            h.tap do
              h[type] = learn_using_split(:train, type).deep_merge!(learn_using_split(:data, type))
            end
          end
        end

        private

        def learn_using_split(split, type)
          return {} if @dataset.send(type).empty?

          execute_queries(split, type) || {}
        end

        def fetch_df(split, type)
          @dataset.send(type).send(split, all_columns: true)
        end

        def execute_queries(split, type)
          @fetched = nil

          columns.reduce({}) do |h, column|
            h.tap do
              next if skip_processing?(column, type)

              adapter = Eager::Query.new(@dataset, column).adapter
              next unless adapter.present?

              @fetched ||= fetch_df(split, type)
              h[column.name] = adapter.new(@dataset, column).execute(split, @fetched)
            end
          end
        end
      end
    end
  end
end
