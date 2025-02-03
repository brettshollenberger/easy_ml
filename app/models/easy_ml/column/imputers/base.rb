module EasyML
  class Column
    class Imputers
      class Base
        attr_accessor :column, :dataset, :preprocessing_step

        def initialize(column, preprocessing_step)
          @column = column
          @dataset = column.dataset
          @preprocessing_step = preprocessing_step.with_indifferent_access
        end

        def params
          @preprocessing_step.dig(:params)
        end

        def method
          @preprocessing_step.dig(:method)
        end

        def anything?
          true
        end

        def transform(df)
          raise "Method not implemented"
        end
      end
    end
  end
end
