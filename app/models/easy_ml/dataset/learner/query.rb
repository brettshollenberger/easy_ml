module EasyML
  class Dataset
    class Learner
      class Query
        attr_reader :dataset, :column, :dtype, :raw_dtype

        def initialize(dataset, column)
          @dataset = dataset
          @column = column
          begin
            # TODO: LAZIFY THIS
            @dtype = column.datatype || EasyML::Data::PolarsColumn.determine_type(column.raw.data[column.name])
            @raw_dtype = column.raw_dtype
          rescue => e
            raise "Unable to find column #{column.name}. If this column is computed by a feature, you forgot to declare computes_columns"
          end
        end

        def execute(split)
          adapter.execute(split)
        end
      end
    end
  end
end
