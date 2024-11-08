require_relative "split"

module EasyML
  module Data
    class Dataset
      module Splits
        class FileSplit < Split
          include GlueGun::DSL
          include EasyML::Data::Utils

          attribute :dir, :string
          attribute :polars_args, :hash, default: {}
          attribute :max_rows_per_file, :integer, default: 1_000_000
          attribute :batch_size, :integer, default: 10_000
          attribute :verbose, :boolean, default: false

          def initialize(options)
            super
            FileUtils.mkdir_p(dir)
          end

          def save(segment, df)
            segment_dir = File.join(dir, segment.to_s)
            FileUtils.mkdir_p(segment_dir)

            file_path = new_file_path_for_segment(segment)
            df.write_parquet(file_path)
          end

          def read(segment, split_ys: false, target: nil, drop_cols: [], filter: nil, limit: nil, select: nil)
            files = files_for_segment(segment)
            return split_ys ? [nil, nil] : nil if files.empty?

            # Process all files together when no block is given
            lazy_frames = files.map { |file| Polars.scan_parquet(file) }
            combined_lazy_df = Polars.concat(lazy_frames)

            # Apply the predicate filter if given
            combined_lazy_df = combined_lazy_df.filter(filter) if filter
            # Apply select columns if provided
            combined_lazy_df = combined_lazy_df.select(select) if select.present?

            # Apply drop columns
            drop_cols &= combined_lazy_df.columns
            combined_lazy_df = combined_lazy_df.drop(drop_cols) unless drop_cols.empty?

            # Collect the DataFrame (execute the lazy operations)
            combined_lazy_df = combined_lazy_df.limit(limit) if limit
            df = combined_lazy_df.collect

            split_features_targets(df, split_ys, target)
          end

          def cleanup
            FileUtils.rm_rf(dir)
            FileUtils.mkdir_p(dir)
          end

          def split_at
            return nil if output_files.empty?

            output_files.map { |file| File.mtime(file) }.max
          end

          def num_batches(segment)
            files_for_segment(segment).count
          end

          private

          def df(path)
            filtered_args = filter_polars_args(Polars.method(:read_parquet))
            Polars.read_parquet(path, **filtered_args)
          end

          def filter_polars_args(method)
            supported_params = method.parameters.map { |_, name| name }
            polars_args.select { |k, _| supported_params.include?(k) }
          end

          def output_files
            Dir.glob("#{dir}/**/*.parquet")
          end

          def files_for_segment(segment)
            if segment.to_s == "all"
              files_for_segment("train") + files_for_segment("test") + files_for_segment("valid")
            else
              segment_dir = File.join(dir, segment.to_s)
              Dir.glob(File.join(segment_dir, "**/*.parquet")).sort
            end
          end

          def current_file_for_segment(segment)
            segment_dir = File.join(dir, segment.to_s)
            File.join(segment_dir, "#{segment}.parquet")
          end

          def new_file_path_for_segment(segment)
            segment_dir = File.join(dir, segment.to_s)
            file_number = Dir.glob(File.join(segment_dir, "*.parquet")).count
            File.join(segment_dir, "#{segment}_%04d.parquet" % file_number)
          end

          def combine_dataframes(files)
            dfs = files.map { |file| df(file) }
            Polars.concat(dfs)
          end
        end
      end
    end
  end
end
