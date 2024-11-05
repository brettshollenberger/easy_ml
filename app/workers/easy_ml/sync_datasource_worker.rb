module EasyML
  class SyncDatasourceWorker
    include Sidekiq::Job
    MAX_LINE_LENGTH = 65

    sidekiq_options(
      queue: :easy_ml,
      retry: false,
      lock: :until_executed,
      on_conflict: :log,
      lock_args_method: ->(args) { args.first } # Lock based on datasource ID
    )

    def perform(id)
      datasource = EasyML::Datasource.find(id)

      create_event(datasource, "started")

      begin
        datasource.refresh!
        create_event(datasource, "success")
      rescue StandardError => e
        create_event(datasource, "error", e)
        datasource.update(is_syncing: false)
        raise # Re-raise the error to ensure Sidekiq marks the job as failed
      end
    end

    private

    def create_event(datasource, status, error = nil)
      EasyML::Event.create!(
        name: self.class.name.demodulize,
        status: status,
        eventable: datasource,
        stacktrace: format_stacktrace(error)
      )
    end

    def format_stacktrace(error)
      return nil if error.nil?

      topline = error.inspect

      stacktrace = error.binding_locations.select do |loc|
        loc.to_s.match?(/easy_ml/)
      end

      %(#{topline}

        #{stacktrace.join("\n")}
      ).split("\n").map do |l|
        l.gsub(/\s{2,}/,
               " ").strip
      end.flat_map { |line| wrap_text(line, MAX_LINE_LENGTH) }.join("\n")
    end

    def wrap_text(text, max_length)
      text.strip.scan(/.{1,#{max_length}}/)
    end
  end
end
