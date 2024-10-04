module EasyML::Data
  class Datasource
    class PolarsDatasource < Datasource
      attr_reader :df

      def initialize(df:, root_dir: nil)
        @df = df
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

      def last_updated_at
        Time.now # Always return current time as it's in-memory
      end

      def refresh!
        # No need to refresh for in-memory datasource
      end

      def data
        df
      end
    end
  end
end
