module EasyML
  class ApplicationWorker
    include Sidekiq::Worker

    MAX_LINE_LENGTH = 65

    def create_event(model, status, error = nil)
      EasyML::Event.create!(
        name: self.class.name.demodulize,
        status: status,
        eventable: model,
        stacktrace: format_stacktrace(error)
      )
    end

    def handle_error(model, error)
      create_event(model, "error", error)
      model.update!(is_syncing: false)
      Rails.logger.error("#{self.class.name} failed: #{error.message}")
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
