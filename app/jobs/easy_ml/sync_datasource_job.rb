module EasyML
  class SyncDatasourceJob < ApplicationJob
    def perform(id, force = false)
      datasource = EasyML::Datasource.find(id)
      create_event(datasource, "started")

      begin
        datasource.refresh
      rescue StandardError => e
        datasource.update!(is_syncing: false)
        handle_error(datasource, e)
      end
    end
  end
end
