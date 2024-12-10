module EasyML
  class RefreshDatasetWorker < ApplicationWorker
    sidekiq_options(
      queue: :easy_ml,
      retry: false,
      lock: :until_executed,
      on_conflict: :log,
      lock_args_method: ->(args) { args.first },
    )

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
