module EasyML
  module Jobs
    class FinalizeFeatureJob < ApplicationJob
      queue_as :features

      def perform(feature_id)
        feature = EasyML::Feature.find(feature_id)
        feature.update!(
          applied_at: Time.current,
          needs_recompute: false,
        )
      end
    end
  end
end
