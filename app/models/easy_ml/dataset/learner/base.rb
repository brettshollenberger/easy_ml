module EasyML
  class Dataset
    class Learner
      class Base
        attr_reader :dataset, :columns, :type

        def initialize(dataset, columns, type: :raw)
          @dataset = dataset
          @columns = columns
          @type = type
        end

        def skip_processing?(column, type)
          (!column.in_raw_dataset? && type.to_sym != :processed) ||
            (column.one_hot? && type.to_sym == :processed)
        end

        TYPES_ALL = %i(raw clipped processed)
        TYPES_RAW = %i(raw clipped)
        TYPES_PROCESSED = %i(processed)

        def types(type = :all)
          case type
          when :all then TYPES_ALL
          when :raw then TYPES_RAW
          when :processed then TYPES_PROCESSED
          else
            TYPES_ALL
          end
        end
      end
    end
  end
end
