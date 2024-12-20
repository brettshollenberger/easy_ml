require "resque/batched_job"

module EasyML
  class TestBatchJob < BatchJob
    @queue = :easy_ml

    def self.perform(batch_id, id, *args)
      log "Performing job #{id} with args: #{args.inspect}"
    end

    # Hook: After perform batch
    def self.after_batch_hook(batch_id, *args)
      log "Batch completed!!!"
      original_args = fetch_batch_arguments(batch_id)
      log "Batch completed. Original args: #{original_args.inspect}"
    end

    # Batch log method
    def self.log(message)
      File.open(Rails.root.join("tmp", "batch_logs.log"), "a") do |file|
        file.puts("[#{Time.now}] #{message}")
      end
    end
  end
end
