module EasyML
  class RefreshDatasetJob < ApplicationJob
    def perform(id)
      dataset = EasyML::Dataset.find(id)
      return unless dataset.needs_refresh?

      create_event(dataset, "started")

      begin
        dataset.prepare
        dataset.compute_features(async: true)
      rescue StandardError => e
        if Rails.env.test?
          raise e
        end
        handle_error(dataset, e)
      end
    end
  end
end
