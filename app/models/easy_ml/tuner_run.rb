module EasyML
  class TunerRun < ActiveRecord::Base
    self.table_name = "easy_ml_tuner_runs"

    belongs_to :tuner_job

    validates :hyperparameters, presence: true
    validates :trial_number, presence: true, uniqueness: { scope: :tuner_job_id }

    enum status: {
      pending: "pending",
      running: "running",
      completed: "completed",
      failed: "failed"
    }
  end
end
