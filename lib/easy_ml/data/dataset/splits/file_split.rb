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
          attribute :sample, :float, default: 1.0
          attribute :verbose, :boolean, default: false

          def initialize(options)
            super
            FileUtils.mkdir_p(dir)
          end

          def save(segment, df)
            segment_dir = File.join(dir, segment.to_s)
            FileUtils.mkdir_p(segment_dir)

            current_file = current_file_for_segment(segment)
            current_row_count = current_file && File.exist?(current_file) ? df(current_file).shape[0] : 0
            remaining_rows = max_rows_per_file - current_row_count

            while df.shape[0] > 0
              if df.shape[0] <= remaining_rows
                append_to_csv(df, current_file)
                break
              else
                df_to_append = df.slice(0, remaining_rows)
                df = df.slice(remaining_rows, df.shape[0] - remaining_rows)
                append_to_csv(df_to_append, current_file)
                current_file = new_file_path_for_segment(segment)
                remaining_rows = max_rows_per_file
              end
            end
          end

          def read(segment, split_ys: false, target: nil, drop_cols: [], &block)
            files = files_for_segment(segment)

            if block_given?
              result = nil
              total_rows = files.sum { |file| df(file).shape[0] }
              progress_bar = create_progress_bar(segment, total_rows) if verbose

              files.each do |file|
                df = self.df(file)
                df = sample_data(df) if sample < 1.0
                drop_cols &= df.columns
                df = df.drop(drop_cols) unless drop_cols.empty?

                if split_ys
                  xs, ys = split_features_targets(df, true, target)
                  result = process_block_with_split_ys(block, result, xs, ys)
                else
                  result = process_block_without_split_ys(block, result, df)
                end

                progress_bar.progress += df.shape[0] if verbose
              end
              progress_bar.finish if verbose
              result
            elsif files.empty?
              return nil, nil if split_ys

              nil

            else
              combined_df = combine_dataframes(files)
              combined_df = sample_data(combined_df) if sample < 1.0
              drop_cols &= combined_df.columns
              combined_df = combined_df.drop(drop_cols) unless drop_cols.empty?
              split_features_targets(combined_df, split_ys, target)
            end
          end

          def cleanup
            FileUtils.rm_rf(dir)
            FileUtils.mkdir_p(dir)
          end

          def split_at
            return nil if output_files.empty?

            output_files.map { |file| File.mtime(file) }.max
          end

          private

          def read_csv_batched(path)
            Polars.read_csv_batched(path, batch_size: batch_size, **polars_args)
          end

          def df(path)
            Polars.read_csv(path, **polars_args)
          end

          def output_files
            Dir.glob("#{dir}/**/*.csv")
          end

          def files_for_segment(segment)
            segment_dir = File.join(dir, segment.to_s)
            Dir.glob(File.join(segment_dir, "**/*.csv")).sort
          end

          def current_file_for_segment(segment)
            current_file = files_for_segment(segment).last
            return new_file_path_for_segment(segment) if current_file.nil?

            row_count = df(current_file).shape[0]
            if row_count >= max_rows_per_file
              new_file_path_for_segment(segment)
            else
              current_file
            end
          end

          def new_file_path_for_segment(segment)
            segment_dir = File.join(dir, segment.to_s)
            file_number = Dir.glob(File.join(segment_dir, "*.csv")).count
            File.join(segment_dir, "#{segment}_%04d.csv" % file_number)
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
