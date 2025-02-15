module EasyML
  module Data
    class DatasetManager
      class Writer
        class Named < Base
          def store(name)
            clear_unique_id(subdir: name)
            store_to_unique_file(subdir: name)
          end
        end
      end
    end
  end
end
