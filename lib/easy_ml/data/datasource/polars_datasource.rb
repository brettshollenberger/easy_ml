module EasyML::Data
  class Datasource
    class PolarsDatasource < Datasource
      include GlueGun::DSL

      attribute :df
      validate :df_is_dataframe
      def df_is_dataframe
        return if df.nil? || df.is_a?(Polars::DataFrame)

        errors.add(:df, "Must be an instance of Polars::DataFrame")
      end
      attr_accessor :last_updated_at

      def initialize(options)
        super
        @last_updated_at = Time.now
      end

      def in_batches(of: 10_000)
        total_rows = df.shape[0]
        (0...total_rows).step(of) do |start|
          end_index = [start + of, total_rows].min
          yield df.slice(start, end_index - start)
        end
      end

      def files
        [] # No files, as this is in-memory
      end

      def refresh
        # No need to refresh for in-memory datasource
      end

      def refresh!
        # No need to refresh for in-memory datasource
      end

      def data
        df
      end

      def self.serialize(datasource)
        {
          df: JSON.parse(datasource.df.write_json)
        }
      end

      def self.deserialize(options)
        df = options[:df]
        columns = df[:columns].map do |col|
          # Determine the correct data type
          dtype = case col[:datatype]
                  when Hash
                    if col[:datatype][:Datetime]
                      Polars::Datetime.new(col[:datatype][:Datetime][0].downcase.to_sym).class
                    else
                      Polars::Utf8
                    end
                  else
                    Polars.const_get(col[:datatype])
                  end
          # Create a Series for each column
          Polars::Series.new(col[:name], col[:values], dtype: dtype)
        end

        # Create the DataFrame
        options[:df] = Polars::DataFrame.new(columns)
        options
      end
    end
  end
end
