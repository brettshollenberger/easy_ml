module EasyML
  class TrainingJob < ApplicationJob
    class TrainingTimeoutError < StandardError; end

    INACTIVITY_TIMEOUT = 15 # seconds

    def perform(model_id)
      @model = EasyML::Model.find(model_id)
      @last_activity = Time.current
      setup_signal_traps
      # @monitor_thread = start_monitor_thread

      @model.actually_train do |iteration_info|
        @last_activity = Time.current
      end
    ensure
      #   @monitor_thread&.exit
    end

    private

    def setup_signal_traps
      # Handle graceful shutdown on SIGTERM
      Signal.trap("TERM") do
        puts "Received SIGTERM, cleaning up..."
        cleanup("Training process terminated")
        raise TrainingTimeoutError, "Training process terminated"
      end

      # Handle Ctrl+C
      Signal.trap("INT") do
        puts "Received SIGINT, cleaning up..."
        cleanup("Training process interrupted")
        raise TrainingTimeoutError, "Training process interrupted"
      end
    end

    def cleanup(error_message)
      return if @cleaned_up
      @cleaned_up = true
      @model.last_run.update(status: "failed", error_message: error_message, completed_at: Time.current)
      @model.update(is_training: false)
    end

    def start_monitor_thread
      Thread.new do
        while true
          puts "Monitoring activity... #{Time.current - @last_activity}"
          if Time.current - @last_activity >= INACTIVITY_TIMEOUT
            puts "Training process inactive for #{INACTIVITY_TIMEOUT} seconds, terminating..."
            cleanup("Training process timed out")
            Thread.main.raise(TrainingTimeoutError)
            break
          end
          sleep 1
        end
      end
    end
  end
end
