module EasyML
  module Data
    module Splits
      class Split
        include EasyML::Data::Utils

        VALID_SEGMENTS = %w[train test valid all].freeze

        def load_data(segment, **kwargs)
          drop_cols = dataset.drop_columns(all_columns: kwargs[:all_columns] || false)
          kwargs.delete(:all_columns)
          kwargs = kwargs.merge!(drop_cols: drop_cols, target: dataset.target)
          read(segment, **kwargs)
        end

        def save(segment, _df)
          validate_segment!(segment)
          raise NotImplementedError, "Subclasses must implement #save"
        end

        def read(segment, split_ys: false, target: nil, drop_cols: [], **options)
          validate_segment!(segment)
          validate_read_options!(options)
          raise NotImplementedError, "Subclasses must implement #read"
        end

        def data(**kwargs, &block)
          load_data(:all, **kwargs, &block)
        end

        def train(**kwargs, &block)
          load_data(:train, **kwargs, &block)
        end

        def test(**kwargs, &block)
          load_data(:test, **kwargs, &block)
        end

        def valid(**kwargs, &block)
          load_data(:valid, **kwargs, &block)
        end

        def cleanup
          raise NotImplementedError, "Subclasses must implement #cleanup"
        end

        def split_at
          raise NotImplementedError, "Subclasses must implement #split_at"
        end

        protected

        def split_features_targets(df, split_ys, target)
          return df unless split_ys
          raise ArgumentError, "Target column must be specified when split_ys is true" if target.nil?

          xs = df.drop(target)
          ys = df.select(target)
          [xs, ys]
        end

        def validate_segment!(segment)
          segment = segment.to_s
          return if VALID_SEGMENTS.include?(segment)

          raise ArgumentError, "Invalid segment: #{segment}. Must be one of: #{VALID_SEGMENTS.join(", ")}"
        end

        def validate_read_options!(options)
          valid_options = %i[filter limit select unique]
          invalid_options = options.keys - valid_options
          return if invalid_options.empty?

          raise ArgumentError,
                "Invalid options: #{invalid_options.join(", ")}. Valid options are: #{valid_options.join(", ")}"
        end

        private

        def process_block_with_split_ys(block, result, xs, ys)
          case block.arity
          when 3 then result.nil? ? [xs, ys] : block.call(result, xs, ys)
          when 2 then block.call(xs, ys) && result
          else raise ArgumentError, "Block must accept 2 or 3 arguments when split_ys is true"
          end
        end

        def process_block_without_split_ys(block, result, df)
          case block.arity
          when 2 then result.nil? ? df : block.call(result, df)
          when 1 then block.call(df) && result
          else raise ArgumentError, "Block must accept 1 or 2 arguments when split_ys is false"
          end
        end
      end
    end
  end
end
