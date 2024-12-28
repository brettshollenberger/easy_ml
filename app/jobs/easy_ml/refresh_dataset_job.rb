module EasyML
  class RefreshDatasetJob < ApplicationJob
    def perform(id)
      dataset = EasyML::Dataset.find(id)
      puts "Refreshing dataset #{dataset.name}"
      puts "Needs refresh? #{dataset.needs_refresh?}"
      return unless dataset.needs_refresh?

      create_event(dataset, "started")

      begin
        puts "Prepare! #{dataset.name}"
        dataset.prepare
        if dataset.features.needs_recompute.any?
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
