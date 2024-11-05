module EasyML
  class SyncDatasourceWorker
    include Sidekiq::Job

    sidekiq_options queue: :easy_ml, retry: false

    def perform(id)
      datasource = EasyML::Datasource.find(id)
      begin
        datasource.refresh!
      rescue StandardError
        datasource.update(is_syncing: false)
      end
    end
  end
end
