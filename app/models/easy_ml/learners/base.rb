module EasyML
  module Learners
    class Base
      attr_accessor :column, :dataset, :dtype, :select

      def initialize(column)
        @column = column
        @dataset = column.dataset
        @select = dataset.date_column.present? ? [dataset.date_column.name] : []
      end

      def self.adapter(column)
        dtype = EasyML::Data::PolarsColumn.determine_type(column.raw.data[column.name])

        case dtype
        when :float, :integer
          EasyML::Learners::Numeric
        when :string, :text
          EasyML::Learners::String
        when :categorical, :boolean
          EasyML::Learners::Categorical
        when :datetime
          EasyML::Learners::Datetime
        when :null
          EasyML::Learners::Base
        else
          raise "Don't know how to learn from dtype: #{dtype}"
        end
      end

      def learn
        {
          raw: learn_split(column.raw),
          processed: learn_split(column.processed),
        }
      end

      def statistics(df)
        return {} if df.nil?

        {
          num_rows: df.size,
          null_count: df[column.name].null_count || 0,
          last_value: last_value(df),
        }
      end

      def full_dataset_columns
        %i(num_rows null_count)
      end

      def train_columns
        %i(last_value)
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
