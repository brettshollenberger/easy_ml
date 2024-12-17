module EasyML
  class ScheduleRetrainingJob < ApplicationJob
    queue_as :easy_ml

    def perform
      RetrainingJob.active.each do |job|
        job.model.train
      end
    end
  end
end
