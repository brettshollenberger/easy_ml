module EasyML
  class Column
    module Learners
      class Base
        attr_accessor :column, :dataset, :dtype, :select
        include EasyML::Timing

        def initialize(column)
          @column = column
          @dataset = column.dataset
          @select = dataset.date_column.present? ? [dataset.date_column.name] : []
        end

        def self.adapter(column)
          begin
            # LAZY:
            # Deal with lazily determining types...
            dtype = column.datatype || EasyML::Data::PolarsColumn.determine_type(column.raw.data[column.name])
          rescue => e
            raise "Unable to find column #{column.name}. If this column is computed by a feature, you forgot to declare computes_columns"
          end

          case dtype.to_sym
          when :float, :integer
            EasyML::Column::Learners::Numeric
          when :string, :text
            EasyML::Column::Learners::String
          when :categorical
            EasyML::Column::Learners::Categorical
          when :datetime, :date
            EasyML::Column::Learners::Datetime
          when :boolean
            EasyML::Column::Learners::Boolean
          when :null
            EasyML::Column::Learners::Null
          else
            raise "Don't know how to learn from dtype: #{dtype}"
          end
        end

        TYPES_ALL = %i(raw clipped processed)
        TYPES_RAW = %i(raw clipped)
        TYPES_PROCESSED = %i(processed)

        def types(type = :all)
          return TYPES_PROCESSED if !column.in_raw_dataset?

          case type
          when :all then TYPES_ALL
          when :raw then TYPES_RAW
          when :processed then TYPES_PROCESSED
          else
            TYPES_ALL
          end
        end

        def learn(type: :all)
          types(type).each_with_object({}) do |t, h|
            begin
              h[t] = learn_split(column.send(t))
            rescue => e
              puts EasyML::Event.easy_ml_context(e.backtrace)
              raise e
            end
          end
        end

        def full_dataset_statistics(df)
          [num_rows(df), null_count(df)].compact
        end

        def train_statistics(df)
          [last_value(df), most_frequent_value(df)].compact
        end

        def learn_split(split)
          # df = split.data(select: select, lazy: true)
          # train_df = split.train(select: select, lazy: true)
          df = nil
          train_df = nil
          # full_dataset_stats = df.select(full_dataset_statistics(df)).collect.to_hashes.first
          # train_stats = df.select(train_statistics(train_df)).collect.to_hashes.first
          # full_dataset_stats
          #   .merge!(train_stats)
          # .merge!(full_dataset_statistics_eager(df))
          # .merge!(train_statistics_eager(df))
          full_dataset_statistics(df).concat(train_statistics(train_df)).flatten.compact
        end

        def full_dataset_statistics_eager(df)
          {}
        end

        def train_statistics_eager(df)
          {}
        end

        def null_count(df)
          Polars.col(column.name).null_count.alias("#{column.name}_null_count")
        end

        def num_rows(df)
          Polars.col(column.name).count.alias("#{column.name}_num_rows")
        end

        def most_frequent_value(df)
          Polars.col(column.name).mode.first.alias("#{column.name}_most_frequent_value")
        end

        measure_method_timing :learn_split

        def last_value(df)
          return unless dataset.date_column.present?

          Polars.col(column.name)
            .sort_by(dataset.date_column.name, reverse: true, nulls_last: true)
            .filter(Polars.col(column.name).is_not_null)
            .first
            .alias("#{column.name}_last_value")
        end
      end
    end
  end
end
