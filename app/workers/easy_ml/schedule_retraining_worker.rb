module EasyML
  class ScheduleRetrainingWorker
    include Sidekiq::Job

    sidekiq_options queue: :easy_ml, retry: false

    def perform
      RetrainingJob.current.each do |job|
        next unless job.lock!

        begin
          model.train
        rescue StandardError
          job.unlock!
        end
      end
    end
  end
end
