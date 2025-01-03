module EasyML
  class RefreshDatasetJob < ApplicationJob
    def perform(id)
      dataset = EasyML::Dataset.find(id)
      puts "Refreshing dataset #{dataset.name}"
      puts "Needs refresh? #{dataset.needs_refresh?}"
      unless dataset.needs_refresh?
        dataset.update(workflow_status: :ready)
      end

      create_event(dataset, "started")

      begin
        puts "Prepare! #{dataset.name}"
        dataset.prepare
        if dataset.features.needs_fit.any?
          dataset.fit_features(async: true)
          puts "Computing features!"
        else
          dataset.actually_refresh
          puts "Done!"
        end
      rescue StandardError => e
        puts "Error #{e.message}"
        if Rails.env.test?
          raise e
        end
        handle_error(dataset, e)
      end
    end
  end
end
