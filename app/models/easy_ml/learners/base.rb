module EasyML
  module Learners
    class Base
      attr_accessor :column, :dataset, :dtype

      def initialize(column)
        @column = column
        @dataset = column.dataset
      end

      def self.adapter(column)
        dtype = EasyML::Data::PolarsColumn.determine_type(column.raw.data.to_series)

        case dtype
        when :float, :integer
          EasyML::Learners::Numeric
        when :string, :categorical, :text
          EasyML::Learners::Categorical
        else
          raise "Don't know how to learn from dtype: #{dtype}"
        end
        # return {} if series.dtype == Polars::Null
        # field_type =

      end

      def learn
        {
          raw: learn_split(column.raw),
          processed: learn_split(column.processed),
        }
      end

      def statistics(df)
        {
          num_rows: df.size,
          null_count: df[column.name].null_count,
          unique_count: df[column.name].n_unique,
          counts: df[column.name].value_counts.to_hash,
        }
      end

      def full_dataset_columns
        %i(num_rows null_count unique_count counts)
      end

      def learn_split(split)
        df = split.data
        train_df = split.train
        full_dataset_stats = statistics(df).slice(*full_dataset_columns)
        train_stats = statistics(train_df).slice(*train_columns)
        full_dataset_stats.merge!(train_stats)
      end
    end
  end
end
