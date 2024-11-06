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
      EasyML::Support::Lockable.with_lock_client("SyncDatasourceWorker:#{id}") do |client|
        client.lock do
          datasource = EasyML::Datasource.find(id)
          create_event(datasource, "started")

          begin
            sync_datasource(datasource)
          rescue StandardError => e
            handle_error(datasource, e)
          end
        end
      end
    end

    def on_success(_status, options)
      options.symbolize_keys!

      datasource = EasyML::Datasource.find(options[:datasource_id])

      begin
        datasource.after_sync
        create_event(datasource, "success")
      rescue StandardError => e
        handle_error(datasource, e)
      end
    end

    def on_complete(_status, options)
      options.symbolize_keys!

      datasource = EasyML::Datasource.find(options[:datasource_id])
      datasource.update(is_syncing: false)
    end

    private

    def sync_datasource(datasource)
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
    end
  end
end
