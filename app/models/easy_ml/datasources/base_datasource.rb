module EasyML
  module Datasources
    class BaseDatasource
      include ActiveModel::Validations
      include EasyML::Concerns::Configurable

      attr_reader :datasource

      def clean; end

      def before_sync; end

      def after_sync; end

      def initialize(datasource)
        @datasource = datasource
      end

      def query(*)
        raise NotImplementedError
      end

      def in_batches(*)
        raise NotImplementedError
      end

      def files
        raise NotImplementedError
      end

      def last_updated_at
        raise NotImplementedError
      end

      def data
        raise NotImplementedError
      end

      def needs_refresh?
        false
      end

      def refresh
        datasource.syncing do
          # Default implementation does nothing
        end
      end

      def refresh!
        refresh
      end
    end
  end
end
