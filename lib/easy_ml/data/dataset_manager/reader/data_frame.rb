module EasyML
  module Data
    class DatasetManager
      class Reader
        class DataFrame < File
          def query
            return query_dataframes(lazy_frames, schema)
          end

          def list_nulls
            df = lazy_frames
            list_df_nulls(df)
          end

          def schema
            input.schema
          end

          private

          def lazy_frames
            input.lazy
          end
        end
      end
    end
  end
end
