module EasyML
  module Data
    class DatasetManager
      class Writer
        class Partitioned < Base
          class PartitionReasons < EasyML::Reasons
            add_reason "Missing primary key", -> { primary_key.nil? }
            add_reason "Df does not contain primary key", -> { df.columns.exclude?(primary_key) }
            add_reason "Primary key is not numeric", -> { !numeric_primary_key? }
          end
        end
      end
    end
  end
end
