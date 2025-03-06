module EasyML
  module ErrorLogger
    require_relative "error_logger/adapter"

    def self.error(e)
      adapter.error(e)
    end

    private

    def self.adapter
      @adapter ||= EasyML::ErrorLogger::Adapter.new.pick
    end
  end
end
