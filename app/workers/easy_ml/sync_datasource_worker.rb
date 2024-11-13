module EasyML
  class SyncDatasourceWorker < ApplicationWorker
    sidekiq_options(
      queue: :easy_ml,
      retry: false
    )

    def perform(id, force = false)
      datasource = EasyML::Datasource.find(id)
      create_event(datasource, "started")

      begin
        files = sync_datasource(datasource, force)
        datasource.after_sync if files.nil?
      rescue StandardError => e
        handle_error(datasource, e)
        create_event(datasource, e)
      end
    end

    def handle_error(datasource, _error)
      datasource.update!(is_syncing: false)
    end

    def on_success(_status, options)
      options.symbolize_keys!

      datasource = EasyML::Datasource.find(options[:datasource_id])

      begin
        datasource.after_sync
        datasource.update(is_syncing: false)
        create_event(datasource, "success")
      rescue StandardError => e
        handle_error(datasource, e)
      end
    end

    def on_complete(status, options)
      return if status == "success"

      options.symbolize_keys!

      datasource = EasyML::Datasource.find(options[:datasource_id])
      datasource.update(is_syncing: false)
    end

    private

    def sync_datasource(datasource, force = false)
      return unless datasource.should_sync? || force

      datasource.before_sync
      files = datasource.files_to_sync
      return if files.empty?

      batch = Sidekiq::Batch.new
      batch.description = "Syncing datasource #{datasource.id}"
      batch.on(:success, EasyML::SyncDatasourceWorker, datasource_id: datasource.id)
      batch.on(:complete, EasyML::SyncDatasourceWorker, datasource_id: datasource.id)

      batch.jobs do
        files.each do |file|
          EasyML::FileDownloadWorker.perform_async(
            datasource.id,
            file.to_h.slice(:key, :last_modified).to_json
          )
        end
      end
      files
    end
  end
end
