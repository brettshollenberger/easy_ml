module EasyML
  class SyncDatasourceWorker < ApplicationWorker
    sidekiq_options(
      queue: :easy_ml,
      retry: false,
      lock: :until_executed,
      on_conflict: :log,
      lock_args_method: ->(args) { args.first }
    )

    def perform(id)
      datasource = EasyML::Datasource.find(id)
      create_event(datasource, "started")

      begin
        sync_datasource(datasource)
      rescue StandardError => e
        handle_error(datasource, e)
      end
    end

    def on_success(_status, options)
      options.symbolize_keys!

      datasource = EasyML::Datasource.find(options[:datasource_id])
      directory = datasource.send(:synced_directory)

      begin
        directory.send(:after_sync)
        datasource.send(:after_sync)

        create_event(datasource, "success")
      rescue StandardError => e
        handle_error(datasource, e)
      end
    end

    private

    def sync_datasource(datasource)
      directory = datasource.send(:synced_directory)

      datasource.send(:before_sync)
      directory.send(:before_sync)

      files = directory.files_to_sync
      return if files.empty?

      batch = Sidekiq::Batch.new
      batch.description = "Syncing datasource #{datasource.id}"
      batch.on(:success, EasyML::SyncDatasourceWorker, datasource_id: datasource.id)

      batch.jobs do
        files.each do |file|
          EasyML::FileDownloadWorker.perform_async(
            datasource.id,
            file.to_h.slice(:key, :last_modified).to_json
          )
        end
      end
    end
  end
end
