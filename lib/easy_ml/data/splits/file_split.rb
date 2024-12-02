require_relative "split"

module EasyML
  module Data
    module Splits
      class FileSplit < Split
        include GlueGun::DSL
        include EasyML::Data::Utils

        attribute :dir, :string
        attribute :polars_args, :hash, default: {}
        attribute :max_rows_per_file, :integer, default: 1_000_000
        attribute :batch_size, :integer, default: 10_000
        attribute :verbose, :boolean, default: false
        attribute :dataset
        attribute :datasource

        def initialize(options)
          super
          FileUtils.mkdir_p(dir)
        end

        def s3_prefix
          File.join("datasets", dir.split("datasets").last)
        end

        def synced_directory
          datasource_config = datasource.configuration || {}
          @synced_dir ||= EasyML::Data::SyncedDirectory.new(
            root_dir: dir,
            s3_bucket: datasource_config.dig("s3_bucket") || EasyML::Configuration.s3_bucket,
            s3_prefix: s3_prefix,
            s3_access_key_id: EasyML::Configuration.s3_access_key_id,
            s3_secret_access_key: EasyML::Configuration.s3_secret_access_key,
            polars_args: datasource_config.dig("polars_args"),
            cache_for: 0
          )
        end

        def download
          synced_directory.download
        end

        def upload
          synced_directory.upload
        end

        def cp(target_dir)
          puts "copying #{dir} to #{target_dir}"
          FileUtils.mkdir_p(target_dir)

          files_to_move = Dir.glob(Pathname.new(dir).join("**/*")).select { |f| File.file?(f) }

          files_to_move.each do |file|
            target_parts = target_dir.split("/")
            file_parts = file.split("/")
            _, not_shared = file_parts.partition.with_index { |part, index| target_parts[index] == part }
            not_shared = not_shared[1..-1].join("/") # remove leading "processed", "raw", etc

            target_file = File.join(target_dir, not_shared)
            FileUtils.mkdir_p(File.dirname(target_file))
            FileUtils.cp(file, target_file)
          end

          self.class.new(dir: target_dir, **attributes.except("dir"))
        end

        def save(segment, df)
          segment_dir = File.join(dir, segment.to_s)
          FileUtils.mkdir_p(segment_dir)

          file_path = new_file_path_for_segment(segment)
          df.write_parquet(file_path)
          file_path
        end

        def read(segment, split_ys: false, target: nil, drop_cols: [], filter: nil, limit: nil, select: nil,
                 unique: nil, sort: nil, descending: false)
          files = files_for_segment(segment)
          return split_ys ? [nil, nil] : nil if files.empty?

          query_params = {
            filter: filter,
            limit: limit,
            select: select,
            unique: unique,
            drop_cols: drop_cols,
            sort: sort,
            descending: descending
          }.compact

          df = EasyML::Data::PolarsReader.query(files, **query_params)

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

        def files
          files_for_segment("all")
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
