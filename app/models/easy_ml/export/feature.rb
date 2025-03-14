module EasyML
  module Export
    class Feature
      using EasyML::DeepCompact

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
        feature.as_json.except(*EasyML::Feature::UNCONFIGURABLE_COLUMNS).deep_compact.with_indifferent_access
      end
    end
  end
end
