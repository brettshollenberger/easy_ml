module ML
  module Data
    class Dataset
      class InMemorySplit < Split
        attr_accessor :sample

        def initialize(sample: 1.0)
          @sample = sample
          @data = {}
        end

        def save(segment, df)
          @data[segment] = df
        end

        def read(segment, split_ys: false, target: nil, drop_cols: [], &block)
          df = @data[segment]
          return nil if df.nil?

          df = sample_data(df) if sample < 1.0
          drop_cols = drop_cols & df.columns
          df = df.drop(drop_cols) unless drop_cols.empty?

          if block_given?
            if split_ys
              xs, ys = split_features_targets(df, true, target)
              process_block_with_split_ys(block, nil, xs, ys)
            else
              process_block_without_split_ys(block, nil, df)
            end
          else
            split_features_targets(df, split_ys, target)
          end
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