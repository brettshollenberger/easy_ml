module EasyML
  module Data
    class Dataset
      module Splits
        class Split
          include EasyML::Data::Utils

          attr_reader :polars_args, :max_rows_per_file, :batch_size, :sample, :verbose

          def save(segment, df)
            raise NotImplementedError, "Subclasses must implement #save"
          end

          def read(segment, split_ys: false, target: nil, drop_cols: [], &block)
            raise NotImplementedError, "Subclasses must implement #read"
          end

          def train(&block)
            read(:train, &block)
          end

          def test(&block)
            read(:test, &block)
          end

          def valid(&block)
            read(:valid, &block)
          end

          def cleanup
            raise NotImplementedError, "Subclasses must implement #cleanup"
          end

          def split_at
            raise NotImplementedError, "Subclasses must implement #split_at"
          end

          protected

          def split_features_targets(df, split_ys, target)
            raise ArgumentError, "Target column must be specified when split_ys is true" if split_ys && target.nil?

            if split_ys
              xs = df.drop(target)
              ys = df.select(target)
              [xs, ys]
            else
              df
            end
          end

          def sample_data(df)
            return df if sample >= 1.0

            df.sample(n: (df.shape[0] * sample).ceil, seed: 42)
          end

          def create_progress_bar(segment, total_rows)
            ProgressBar.create(
              title: "Reading #{segment}",
              total: total_rows,
              format: "%t: |%B| %p%% %e"
            )
          end

          def process_block_with_split_ys(block, result, xs, ys)
            case block.arity
            when 3
              result.nil? ? [xs, ys] : block.call(result, xs, ys)
            when 2
              block.call(xs, ys)
              result
            else
              raise ArgumentError, "Block must accept 2 or 3 arguments when split_ys is true"
            end
          end

          def process_block_without_split_ys(block, result, df)
            case block.arity
            when 2
              result.nil? ? df : block.call(result, df)
            when 1
              block.call(df)
              result
            else
              raise ArgumentError, "Block must accept 1 or 2 arguments when split_ys is false"
            end
          end
        end
      end
    end
  end
end
