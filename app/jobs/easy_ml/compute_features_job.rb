module EasyML
  class ComputeFeaturesJob < ApplicationJob
    def perform(id)
      dataset = EasyML::Dataset.find(id)
      features = dataset.features.needs_recompute

      batch_features, features = features.partition(&:batchable?)

      jobs = batch_features.flat_map do |feature|
        feature.batch
      end.concat(features.map do |feature|
        {
          feature_id: feature.id,
        }
      end)
      EasyML::ComputeFeatureJob.enqueue_batch(jobs)
    end
  end
end
