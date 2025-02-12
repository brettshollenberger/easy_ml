module EasyML
  module Export
    class Datasource
      UNCONFIGURABLE_COLUMNS = %w(id root_dir created_at updated_at refreshed_at sha)

      def self.to_config(datasource)
        datasource.as_json.except(*UNCONFIGURABLE_COLUMNS).deep_compact.with_indifferent_access
      end
    end
  end
end
