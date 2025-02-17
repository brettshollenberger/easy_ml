module EasyML
  class SyncDatasourceJob < ApplicationJob
    queue_as :easy_ml

    def perform(id)
      datasource = EasyML::Datasource.find(id)
      create_event(datasource, "started")

      begin
        datasource.refresh
        datasource.after_sync
      rescue StandardError => e
        datasource.update!(is_syncing: false)
        handle_error(datasource, e)
      end
    end
  end
end
