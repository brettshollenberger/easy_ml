module EasyML
  class ComputeFeatureJob < BatchJob
    @queue = :easy_ml

    def self.perform(batch_id, options = {})
      options.symbolize_keys!
      feature_id = options.dig(:feature_id)
      feature = EasyML::Feature.find(feature_id)

      feature.fit(options)
    end

    def self.after_batch_hook(batch_id, *args)
      feature_ids = fetch_batch_arguments(batch_id).flatten.map(&:symbolize_keys).pluck(:feature_id).uniq
      EasyML::Feature.where(id: feature_ids).update_all(needs_recompute: false, fit_at: Time.current)

      dataset = EasyML::Feature.find_by(id: feature_ids.first).dataset
      EasyML::RefreshDatasetJob.perform_later(dataset.id)
    end
  end
end
