module EasyML
  class RefreshDatasetJob < ApplicationJob
    def perform(id)
      dataset = EasyML::Dataset.find(id)
      create_event(dataset, "started")

      begin
        dataset.refresh
        create_event(dataset, "success")
      rescue StandardError => e
        handle_error(dataset, e)
      end
    end
  end
end
