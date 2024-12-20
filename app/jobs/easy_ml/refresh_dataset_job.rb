module EasyML
  class RefreshDatasetJob < ApplicationJob
    def perform(id)
      dataset = EasyML::Dataset.find(id)
      return unless dataset.needs_refresh?

      create_event(dataset, "started")

      begin
        if dataset.features.needs_recompute.empty?
          dataset.refresh
          create_event(dataset, "success")
        else
          dataset.prepare
          EasyML::ComputeFeaturesJob.perform_later(dataset.id)
        end
      rescue StandardError => e
        if Rails.env.test?
          raise e
        end
        handle_error(dataset, e)
      end
    end
  end
end
