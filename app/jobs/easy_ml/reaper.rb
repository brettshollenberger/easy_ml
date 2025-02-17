module EasyML
  class Reaper
    class << self
      def list_workers
        Resque::Worker.all.map do |worker|
          if worker.working?
            job = worker.job
            args = job.dig("payload", "args")&.first
            {
              worker: worker,
              working: true,
              class: args.is_a?(Hash) ? args.dig("job_class") : nil,
              args: args.is_a?(Hash) ? args.dig("arguments") : nil,
              pid: worker.pid,
            }
          else
            { working: false, class: nil, pid: nil }
          end
        end
      end

      def find_job(worker_class, *args, &block)
        list_workers.select do |config|
          selected = config.dig(:class) == worker_class.to_s
          if block_given?
            selected &&= yield(config)
          else
            selected &= config.dig(:args) == args
          end
          selected
        end
      end

      def kill(worker_class, *args, &block)
        find_job(worker_class, *args, &block).each do |job|
          begin
            # Send HUP signal to the process
            Process.kill("USR1", job[:pid])

            # Remove the worker from Redis so it doesn't show up as a zombie
            # in the Resque web interface. This is important because:
            # 1. It keeps the interface clean
            # 2. Prevents confusion about running workers
            # 3. Allows proper worker cleanup in Redis
            job[:worker].done_working
          rescue Errno::ESRCH
            # Process already gone, but still try to clean up Redis
            begin
              job[:worker].done_working
            rescue => e
              # Redis cleanup failed, worker might already be unregistered
              puts "Failed to unregister worker: #{e.message}"
            end
          end
        end
      end
    end
  end
end
