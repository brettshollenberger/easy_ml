module EasyML
  class ApplicationJob < ActiveJob::Base
    @queue = :easy_ml
    queue_as :easy_ml

    def create_event(model, status, error = nil)
      EasyML::Event.create_event(model, status, error)
    end

    def handle_error(model, error)
      EasyML::Event.handle_error(model, error)
    end

    def format_stacktrace(error)
      EasyML::Event.format_stacktrace(error)
    end

    def wrap_text(text, max_length)
      EasyML::Event.wrap_text(text, max_length)
    end
  end
end
