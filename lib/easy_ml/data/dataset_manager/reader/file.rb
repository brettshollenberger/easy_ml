module EasyML
  module Data
    class DatasetManager
      class Reader
        class File < Base

          def query
            return query_dataframes(lazy_frames) unless batch_size.present?
            return Batch.new(options, block).query
          end

          def schema
            @schema ||= Polars.read_parquet_schema(files.first)
          end

        private

          def dataframe
            @dataframe = Polars.concat(lazy_frames)
          end

          def lazy_frames
            return @lazy_frames if @lazy_frames

            @lazy_frames = files.map do |file|
              case Pathname.new(file).extname.gsub(/\./, "")
              when "csv"
                Polars.scan_csv(file)
              when "parquet"
                Polars.scan_parquet(file)
              end
            end
          end

        end
      end
    end
  end