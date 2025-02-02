module EasyML
  module Learners
    class Numeric < Base
      def full_dataset_columns
        %i(num_rows null_count unique_count counts)
      end

      def train_columns
        %i(mean median min max std last_value)
      end

      def statistics(df)
        super(df).merge!({
          mean: df[column.name].mean,
          median: df[column.name].median,
          min: df[column.name].min,
          max: df[column.name].max,
          std: df[column.name].std,
          last_value: last_value(df),
        }.compact)
      end

      def last_value(df)
        if dataset.date_column.present?
          df.filter(Polars.col(column.name).is_not_null)
            .sort(dataset.date_column.name)[column.name][-1]
        end
      end
    end
  end
end
