module EasyML
  module Data
    class DatasetManager
      class Reader
        class Base
          EasyML::Data::DatasetManager::Reader::DEFAULTS.each do |k, _|
            attr_accessor k
          end
          attr_accessor :block
          attr_accessor :options
          attr_accessor :files

          def initialize(options, &block)
            options.each do |k,v|
              send("#{k}=", v)
            end
            @block = block
            @options = options
            @files = options.dig(:input)
          end

          def query
            raise "Not implemented"
          end

        private
          def query_dataframes(dfs)
            # Apply the predicate filter if given
            dfs = dfs.filter(filter) if filter
            # Apply select columns if provided
            dfs = dfs.select(select) if select.present?
            dfs = dfs.unique if unique

            # Apply sorting if provided
            dfs = dfs.sort(sort, reverse: descending) if sort

            # Apply drop columns
            drop_cols &= dfs.columns
            dfs = dfs.drop(drop_cols) unless drop_cols.empty?

            # Collect the DataFrame (execute the lazy operations)
            dfs = dfs.limit(limit) if limit
            lazy ? df : df.collect
          end

        end
      end
    end
  end
end