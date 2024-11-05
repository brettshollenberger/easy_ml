module EasyML
  class SyncDatasourceWorker
    include Sidekiq::Job

    sidekiq_options queue: :easy_ml, retry: false

    def perform(id)
      datasource = EasyML::Datasource.find(id)

      create_event(datasource, "started")

      begin
        datasource.refresh!
        create_event(datasource, "success")
      rescue StandardError => e
        create_event(datasource, "error", e.full_message)
        datasource.update(is_syncing: false)
        raise # Re-raise the error to ensure Sidekiq marks the job as failed
      end
    end

    private

    def create_event(datasource, status, stacktrace = nil)
      EasyML::Event.create!(
        name: self.class.name.demodulize,
        status: status,
        eventable: datasource,
        stacktrace: stacktrace
      )
    end
  end
end
