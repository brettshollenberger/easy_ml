module EasyML
  class RefreshDatasetJob < ApplicationJob
    @queue = :easy_ml

    def perform(id)
      begin
        dataset = EasyML::Dataset.find(id)

        puts "Refreshing dataset #{dataset.name}"
        unless dataset.needs_refresh?
          dataset.update(workflow_status: :ready)
        end

        create_event(dataset, "started")

        dataset.unlock!
        dataset.refreshing do
          dataset.prepare
          if dataset.features.needs_fit.any?
            dataset.fit_features(async: true)
          else
            dataset.after_fit_features
          end
        end
      end
    end
  end
end
