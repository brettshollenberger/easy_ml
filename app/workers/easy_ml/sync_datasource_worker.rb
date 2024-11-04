module EasyML
  class SyncDatasourceWorker
    include Sidekiq::Job

    sidekiq_options queue: :easy_ml, retry: false

    def perform(id)
      EasyML::Datasource.find(id).refresh
    end
  end
end
