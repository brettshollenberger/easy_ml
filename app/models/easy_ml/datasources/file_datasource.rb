module EasyML
  module Datasources
    class FileDatasource < BaseDatasource
      delegate :query, :convert_to_parquet, :sha, to: :reader

      def after_sync
        reader.normalize
      end

      def in_batches(&block)
        reader.in_batches(&block)
      end

      def all_files
        reader.all_files
      end

      def files
        reader.files
      end

      def last_updated_at
        files.map { |file| File.mtime(file) }.max
      end

      def needs_refresh?
        false
      end

      def data
        return @combined_df if @combined_df.present?

        combined_df = nil
        reader.in_batches do |df|
          combined_df = combined_df.nil? ? df : combined_df.vstack(df)
        end
        @combined_df = combined_df
      end

      def exists?
        Dir.glob(File.join(datasource.root_dir, "**/*.{csv,parquet}")).any?
      end

      def error_not_exists
        "Expected to find datasource files at #{datasource.root_dir}"
      end

      private

      def reader
        @reader ||= EasyML::Data::PolarsReader.new(
          root_dir: datasource.root_dir,
          polars_args: (datasource.configuration || {}).dig("polars_args"),
        )
      end
    end
  end
end
