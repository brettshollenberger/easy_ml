module EasyML::Data
  class Datasource
    class FileDatasource < Datasource
      attr_reader :root_dir, :polars_args

      def initialize(root_dir:, polars_args: {})
        @root_dir = root_dir
        @polars_args = polars_args
      end

      def in_batches(of: 10_000)
        files.each do |file|
          df = Polars.read_csv(file, **polars_args)
          yield df
        end
      end

      def files
        Dir.glob(File.join(root_dir, "**/*.csv")).sort
      end

      def last_updated_at
        files.map { |file| File.mtime(file) }.max
      end

      def refresh!
        # No need to refresh for directory-based datasource
      end

      def data
        combined_df = nil
        files.each do |file|
          df = Polars.read_csv(file, **polars_args)
          combined_df = combined_df.nil? ? df : combined_df.vstack(df)
        end
        combined_df
      end
    end
  end
end
