module EasyML
  module Export
    class Splitter
      UNCONFIGURABLE_COLUMNS = %w[id created_at updated_at dataset_id]

      def self.to_config(splitter)
        return nil unless splitter.present?

        splitter.as_json.except(*UNCONFIGURABLE_COLUMNS).deep_compact.with_indifferent_access
      end
    end
  end
end
