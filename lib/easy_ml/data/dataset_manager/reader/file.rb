module EasyML
  module Data
    class DatasetManager
      class Reader
        class File < Base

          def query
            return query_dataframes(dataframe, schema) unless batch_size.present?
            return Batch.new(options, &block).query
          end

          def schema
            @schema ||= Polars.read_parquet_schema(files.first)
          end

          def files
            @files ||= Dir.glob(::File.join(root_dir, "**/*.{parquet}"))
          end

        private
          def root_dir
            @root_dir ||= input.is_a?(Pathname) ? input : Pathname.new(input)
          end

          def dataframe
            @dataframe = Polars.concat(lazy_frames)
          end

          def lazy_frames(files=nil)
            return @lazy_frames if @lazy_frames

            files ||= self.files
            @lazy_frames = files.map do |file|
              Polars.scan_parquet(file)
            end
          end

        end
      end
    end
  end
end

require_relative "batch"