module EasyML
  class RetrainingWorker
    include Sidekiq::Job

    sidekiq_options queue: :easy_ml, retry: true

    def perform(retraining_run_id)
      retraining_run = RetrainingRun.find(retraining_run_id)
      retraining_run.perform_retraining!
      retraining_run.retraining_job.unlock!
    end
  end
end
