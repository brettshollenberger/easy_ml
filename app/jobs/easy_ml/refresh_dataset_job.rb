module EasyML
  class RefreshDatasetJob < ApplicationJob
    def perform(id)
      dataset = EasyML::Dataset.find(id)
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
        handle_error(dataset, e)
      end
    end
  end
end
