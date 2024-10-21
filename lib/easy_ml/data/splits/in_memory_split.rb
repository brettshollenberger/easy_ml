module EasyML
  module Data
    module Splits
      class InMemorySplit < Split
        include GlueGun::DSL

        def initialize(options)
          super
          @data = {}
        end

        def save(segment, df)
          @data[segment] = df
        end

        def read(segment, split_ys: false, target: nil, drop_cols: [], filter: nil)
          df = if segment.to_s == "all"
                 Polars.concat(%i[train test valid].map { |segment| @data[segment] })
               else
                 @data[segment]
               end
          return nil if df.nil?

          df = df.filter(filter) if filter.present?
          drop_cols &= df.columns
          df = df.drop(drop_cols) unless drop_cols.empty?

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
