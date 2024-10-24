module EasyML::Data
  class Datasource
    class FileDatasource < Datasource
      include GlueGun::DSL

      attribute :root_dir, :string
      attribute :polars_args, :hash, default: {}

      def polars_args=(args)
        args[:dtypes] = args[:dtypes].stringify_keys if args.key?(:dtypes)
        super(args)
      end

      def in_batches(&block)
        reader.in_batches(&block)
      end

      def files
        reader.files
      end

      def last_updated_at
        files.map { |file| File.mtime(file) }.max
      end

      def refresh
        # No need to refresh for directory-based datasource
      end

      def refresh!
        # No need to refresh for directory-based datasource
      end

      def data
        return @combined_df if @combined_df.present?

        combined_df = nil
        reader.in_batches do |df|
          combined_df = combined_df.nil? ? df : combined_df.vstack(df)
        end
        @combined_df = combined_df
      end

      def serialize
        attributes
      end

      private

      def reader
        return @reader if @reader

        @reader = EasyML::PolarsReader.new(
          root_dir: root_dir,
          polars_args: polars_args
        )
      end
    end
  end
end
