module EasyML
  class ScheduleRetrainingJob < ApplicationJob
    @queue = :easy_ml

    def perform
      RetrainingJob.active.each do |job|
        job.model.train
      end
    end
  end
end
