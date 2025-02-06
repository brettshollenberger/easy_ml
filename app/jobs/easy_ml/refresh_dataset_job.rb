module EasyML
  class RefreshDatasetJob < ApplicationJob
    def perform(id)
      begin
        dataset = EasyML::Dataset.find(id)

        puts "Refreshing dataset #{dataset.name}"
        unless dataset.needs_refresh?
          dataset.update(workflow_status: :ready)
        end

        create_event(dataset, "started")

        dataset.unlock!
        dataset.prepare
        if dataset.features.needs_fit.any?
          dataset.fit_features(async: true)
        else
          dataset.actually_refresh
        end
      rescue StandardError => e
        if Rails.env.test?
          raise e
        end
        dataset.update(workflow_status: :failed)
        handle_error(dataset, e)
      end
    end
  end
end
