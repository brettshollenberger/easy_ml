module EasyML
  class SyncDatasourceWorker
    include Sidekiq::Worker
    MAX_LINE_LENGTH = 65

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

    def create_event(datasource, status, error = nil)
      EasyML::Event.create!(
        name: self.class.name.demodulize,
        status: status,
        eventable: datasource,
        stacktrace: format_stacktrace(error)
      )
    end

    def handle_error(datasource, error)
      create_event(datasource, "error", error)
      datasource.update!(is_syncing: false)
      Rails.logger.error("Datasource sync failed: #{error.message}")
    end

    def format_stacktrace(error)
      return nil if error.nil?

      topline = error.inspect

      stacktrace = error.backtrace.select do |loc|
        loc.match?(/easy_ml/)
      end

      %(#{topline}

        #{stacktrace.join("\n")}
      ).split("\n").map do |l|
        l.gsub(/\s{2,}/, " ").strip
      end.flat_map { |line| wrap_text(line, MAX_LINE_LENGTH) }.join("\n")
    end

    def wrap_text(text, max_length)
      text.strip.scan(/.{1,#{max_length}}/)
    end
  end
end
