# frozen_string_literal: true

module EasyML
  module ErrorLogger
    class RollbarAdapter < Adapter
      def error(e)
        Rollbar.error(e)
      end

      def warning(e)
        Rollbar.warning(e)
      end

      def info(e)
        Rollbar.info(e)
      end

      def self.use?
        ENV["ROLLBAR_ACCESS_TOKEN"].present?
      end
    end
  end
end