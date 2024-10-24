module ML
  module Data
    class Datasource
      def in_batches(of: 10_000)
        raise NotImplementedError, "Subclasses must implement #in_batches"
      end

      def files
        raise NotImplementedError, "Subclasses must implement #files"
      end

      def last_updated_at
        raise NotImplementedError, "Subclasses must implement #last_updated_at"
      end

      def refresh
        raise NotImplementedError, "Subclasses must implement #refresh"
      end

      def refresh!
        raise NotImplementedError, "Subclasses must implement #refresh!"
      end

      def data
        raise NotImplementedError, "Subclasses must implement #data"
      end

      require_relative "datasource/s3_datasource"
      require_relative "datasource/file_datasource"
      require_relative "datasource/polars_datasource"
      require_relative "datasource/merged_datasource"
    end
  end
end
