module EasyML
  module Data
    module Splits
      class InMemorySplit < Split
        def initialize(_options = {})
          @data = {}
        end

        def save(segment, df)
          @data[segment] = df
        end

        def read(segment, split_ys: false, target: nil, drop_cols: [], filter: nil, limit: nil, select: nil,
                 unique: nil)
          df = if segment.to_s == "all"
                 Polars.concat(EasyML::Dataset::SPLIT_ORDER.map { |segment| @data[segment] })
               else
                 @data[segment]
               end
          return nil if df.nil?

          df = df.filter(filter) if filter.present?
          drop_cols &= df.columns
          df = df.drop(drop_cols) unless drop_cols.empty?
          df = df.unique if unique

          split_features_targets(df, split_ys, target)
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
