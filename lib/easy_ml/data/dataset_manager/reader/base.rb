module EasyML
  module Data
    class DatasetManager
      class Reader
        class Base
          DEFAULTS = {
            drop_cols: [],
            filter: nil,
            limit: nil,
            select: nil,
            unique: nil,
            sort: nil,
            descending: false,
            batch_size: nil,
            batch_start: nil,
            batch_key: nil,
            lazy: false,
          }

          DEFAULTS.each do |k, _|
            attr_accessor k
          end
          attr_accessor :block, :options, :input
          attr_accessor :options

          def initialize(options, &block)
            options = apply_defaults(options)
            @block = block
            @options = options
          end

          def query
            raise "Not implemented"
          end

        private
          def apply_defaults(kwargs)
            options = kwargs.dup

            DEFAULTS.each do |k, default|
              unless options.key?(k)
                options[k] = default
              end
            end

            options.each do |k,v|
              send("#{k}=", v)
            end

            options
          end

          def query_dataframes(df, schema)
            # Apply the predicate filter if given
            df = df.filter(filter) if filter
            # Apply select columns if provided
            df = df.select(select) if select.present?
            df = df.unique if unique

            # Apply sorting if provided
            df = df.sort(sort, reverse: descending) if sort

            # Apply drop columns
            drop_cols = self.drop_cols
            drop_cols &= schema.keys
            df = df.drop(drop_cols) unless drop_cols.empty?

            # Collect the DataFrame (execute the lazy operations)
            df = df.limit(limit) if limit
            lazy ? df : df.collect
          end

        end
      end
    end
  end
end