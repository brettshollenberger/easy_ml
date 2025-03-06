# frozen_string_literal: true

module EasyML
  module ErrorLogger
    class Adapter
      require_relative "rollbar_adapter"

      ADAPTERS = [RollbarAdapter]

      def pick
        adapter_class = ADAPTERS.find { |a| a.use? }
        adapter_class.new
      end
    end
  end
end