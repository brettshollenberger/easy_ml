module EasyML
  module Export
    class Splitter
      UNCONFIGURABLE_COLUMNS = [:id, :dataset_id].freeze

      def self.to_config(splitter)
        return nil unless splitter.present?

        splitter.as_json.except(*UNCONFIGURABLE_COLUMNS)
      end
    end
  end
end
