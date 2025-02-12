module EasyML
  module Export
    class Feature
      UNCONFIGURABLE_COLUMNS = %w(
        id
        created_at
        updated_at
        dataset_id
        sha
        applied_at
        fit_at
        needs_fit
        workflow_status
        refresh_every
      ).freeze

      def self.to_config(feature)
        feature.as_json.except(*EasyML::Feature::UNCONFIGURABLE_COLUMNS)
      end
    end
  end
end
