module EasyML
  class ScheduleRetrainingWorker
    include Sidekiq::Job

    sidekiq_options queue: :easy_ml, retry: false

    def perform
      RetrainingJob.current.each do |job|
        next unless job.should_run?
        next unless job.lock_job!

        begin
          model.train
        rescue StandardError
          job.unlock_job!
        end
      end
    end
  end
end
