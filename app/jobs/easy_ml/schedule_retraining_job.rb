module EasyML
  class ScheduleRetrainingJob < ApplicationJob
    def perform
      RetrainingJob.current.each do |job|
        next unless job.should_run?

        model.train
      end
    end
  end
end
