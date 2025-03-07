module EasyML
  module Data
    module Splits
      class InMemorySplit < Split
        attr_accessor :dataset

        def initialize(options = {})
          @data = {}
          @dataset = options[:dataset]
        end

        # We don't backup in-memory splits to s3
        def download; end

        def upload; end

        def files
          []
        end

        def save(segment, df)
          @data[segment] = df
        end

        def read(segment, split_ys: false, target: nil, drop_cols: [], filter: nil, limit: nil, select: nil,
                          unique: nil, sort: nil, descending: false)
          return nil if @data.keys.none?

          df = if segment.to_s == "all"
              Polars.concat(EasyML::Dataset::SPLIT_ORDER.map { |segment| @data[segment] }.compact)
            else
              @data[segment]
            end
          return nil if df.nil?

          df = EasyML::Data::PolarsInMemory.query(df, drop_cols: drop_cols, filter: filter, limit: limit, select: select,
                                                      unique: unique, sort: sort, descending: descending)

          split_features_targets(df, split_ys, target)
        end

        def query(**kwargs)
          read("all", **kwargs)
        end

        def cleanup
          @data.clear
        end

        def split_at
          @data.keys.empty? ? nil : Time.now
        end
      end
    end
  end
end
