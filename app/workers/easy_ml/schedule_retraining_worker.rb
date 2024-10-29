module EasyML
  class ScheduleRetrainingWorker
    include Sidekiq::Job

    sidekiq_options queue: :easy_ml, retry: false

    def perform
      RetrainingJob.current.each do |job|
        next unless job.lock!

        begin
          run = job.retraining_runs.create!(status: "pending")
          RetrainingWorker.perform_async(run.id)
        rescue StandardError
          job.unlock!
        end
      end
    end
  end
end
