module EasyML
  class RetrainingRun < ActiveRecord::Base
    self.table_name = "easy_ml_retraining_runs"

    belongs_to :retraining_job
    belongs_to :tuner_job, optional: true
    validates :status, presence: true

    enum status: {
      pending: "pending",
      running: "running",
      completed: "completed",
      failed: "failed"
    }

    validates :status, presence: true

    after_create :update_job_last_run

    private

    def update_job_last_run
      retraining_job.update(last_run_at: Time.current)
    end
  end
end
