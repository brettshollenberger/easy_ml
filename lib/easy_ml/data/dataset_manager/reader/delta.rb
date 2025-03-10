module EasyML
  module Data
    class DatasetManager
      class Reader
        class Delta < Base
          attr_accessor :table, :starting_version

          def initialize(options = {})
            super
            @starting_version = options.dig(:starting_version)
            initialize_delta_table
          end

          def query
            return query_with_changes if starting_version
            return query_current_version
          end

          def schema
            @schema ||= table.schema
          end

          # Get changes since a specific version
          def changes_since(version)
            table.load_cdf(
              starting_version: version,
              ending_version: nil, # Latest version
            )
          end

          private

          def query_with_changes
            df = table.load_cdf(
              starting_version: starting_version,
              ending_version: nil,
            )

            query_dataframes(df, schema)
          end

          def query_current_version
            df = table.to_polars(
              eager: !lazy,
              columns: select,
            )

            # Apply additional query transformations
            query_dataframes(df, schema)
          end

          def initialize_delta_table
            @table = DeltaLake::Table.new(table_uri)
          rescue DeltaLake::TableNotFoundError
            @table = nil
          end

          def table_uri
            "file://#{input}"
          end
        end
      end
    end
  end
end
