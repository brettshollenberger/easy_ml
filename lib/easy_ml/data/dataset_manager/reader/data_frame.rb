
module EasyML
  module Data
    class DatasetManager
      class Reader
        class DataFrame < File
          def query
            return query_dataframes(lazy_frames)
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