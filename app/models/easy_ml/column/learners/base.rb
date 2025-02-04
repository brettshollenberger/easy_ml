module EasyML
  class Column
    module Learners
      class Base
        attr_accessor :column, :dataset, :dtype, :select

        def initialize(column)
          @column = column
          @dataset = column.dataset
          @select = dataset.date_column.present? ? [dataset.date_column.name] : []
        end

        def self.adapter(column)
          begin
            dtype = EasyML::Data::PolarsColumn.determine_type(column.raw.data[column.name])
          rescue => e
            raise "Unable to find column #{column.name}. If this column is computed by a feature, you forgot to declare computes_columns"
          end

          case dtype
          when :float, :integer
            EasyML::Column::Learners::Numeric
          when :string, :text
            EasyML::Column::Learners::String
          when :categorical
            EasyML::Column::Learners::Categorical
          when :datetime, :date
            EasyML::Column::Learners::Datetime
          when :boolean
            EasyML::Column::Learners::Base
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
            h[t] = learn_split(column.send(t))
          end
        end

        def statistics(df)
          return {} if df.nil?

          {
            num_rows: df.size,
            null_count: df[column.name].null_count || 0,
            last_value: last_value(df),
            most_frequent_value: df[column.name].mode.sort.to_a&.first,
          }
        end

        def full_dataset_columns
          %i(num_rows null_count)
        end

        def train_columns
          %i(last_value most_frequent_value)
        end

        def learn_split(split)
          df = split.data(select: select)
          train_df = split.train(select: select)
          full_dataset_stats = statistics(df).compact.slice(*full_dataset_columns)
          train_stats = statistics(train_df).compact.slice(*train_columns)
          full_dataset_stats.merge!(train_stats)
        end

        def last_value(df)
          return unless dataset.date_column.present?
          return nil if df.empty? || !df.columns.include?(dataset.date_column.name)

          # Sort by date and get the last non-null value
          sorted_df = df.sort(dataset.date_column.name, reverse: true)
          last_value = sorted_df
            .filter(Polars.col(column.name).is_not_null)
            .select(column.name)
            .head(1)
            .item

          last_value
        end
      end
    end
  end
end
