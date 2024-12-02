module EasyML
  module Datasources
    class PolarsDatasource < BaseDatasource
      validates :df, presence: true
      add_configuration_attributes :df

      def query(drop_cols: [], filter: nil, limit: nil, select: nil, unique: nil, sort: nil, descending: false)
        return if df.nil?

        df = self.df.clone
        df = df.filter(filter) if filter
        df = df.select(select) if select.present?
        df = df.unique if unique
        drop_cols &= df.columns
        df = df.drop(drop_cols) unless drop_cols.empty?
        df = df.sort(sort, reverse: descending) if sort
        df = df.limit(limit) if limit
        df
      end

      def in_batches(of: 10_000)
        total_rows = df.shape[0]
        (0...total_rows).step(of) do |start|
          end_index = [start + of, total_rows].min
          yield df.slice(start, end_index - start)
        end
      end

      def all_files
        []
      end

      def files
        []
      end

      def last_updated_at
        datasource.updated_at
      end

      def data
        df
      end

      def df
        datasource.df
      end

      def exists?
        df.present?
      end

      def error_not_exists
        "Must have a dataframe"
      end

      def store_in_configuration
        return unless df

        datasource.configuration = (datasource.configuration || {}).merge(
          "df" => JSON.parse(df.write_json)
        )
      end

      def read_from_configuration
        return unless datasource.configuration&.key?("df")

        df_data = datasource.configuration["df"]
        return unless df_data.present? && df_data.key?("columns")

        columns = df_data["columns"].map do |col|
          dtype = case col["datatype"]
                  when Hash
                    if col["datatype"]["Datetime"]
                      Polars::Datetime.new(col["datatype"]["Datetime"][0].downcase.to_sym).class
                    else
                      Polars::Utf8
                    end
                  else
                    Polars.const_get(col["datatype"])
                  end
          Polars::Series.new(col["name"], col["values"], dtype: dtype)
        end

        datasource.df = Polars::DataFrame.new(columns)
      end
    end
  end
end
