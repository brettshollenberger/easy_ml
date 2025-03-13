module EasyML
  class Dataset
    class Learner
      class Lazy < Base
        def learn
          # types.map
          types.reduce({}) do |h, type|
            h.tap do
              h[type] = learn_using_split(:train, type).deep_merge!(learn_using_split(:data, type))
            end
          end
        end

        private

        def learn_using_split(split, type)
          return {} if @dataset.send(type).empty?

          get_column_statistics(run_queries(split, type))
        end

        def run_queries(split, type)
          queries = build_queries(split, type)

          begin
            dataset.columns.apply_clip(
              @dataset.send(type).send(split, all_columns: true, lazy: true)
            )
            .select(queries).collect
          rescue => e
            problematic_query = queries.detect { 
              begin
                dataset.send(type).send(split, all_columns: true, lazy: true).select(queries).collect
                false
              rescue => e
                true
              end
            }
            raise "Query failed for column #{problematic_query}, likely wrong datatype"
          end
        end

        def get_column_statistics(query_results)
          query_results.columns.group_by { |k| k.split("__").first }.reduce({}) do |h, (k, v)|
            h.tap do
              h[k] ||= {}
              v.each do |col|
                statistic_name = col.split("__").last
                h[k][statistic_name] = query_results[col][0]
              end
            end
          end
        end

        def build_queries(split, type)
          columns.flat_map do |column|
            next if skip_processing?(column, type)

            query = Lazy::Query.new(@dataset, column)
            query_adapter = query.adapter.new(@dataset, column)
            query_adapter.execute(split)
          end.compact
        end
      end
    end
  end
end
