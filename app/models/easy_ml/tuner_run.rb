# == Schema Information
#
# Table name: easy_ml_tuner_runs
#
#  id              :bigint           not null, primary key
#  tuner_job_id    :bigint           not null
#  hyperparameters :json             not null
#  value           :float
#  trial_number    :integer
#  status          :string
#  wandb_url       :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
module EasyML
  class TunerRun < ActiveRecord::Base
    self.table_name = "easy_ml_tuner_runs"

    belongs_to :tuner_job

    validates :hyperparameters, presence: true
    validates :trial_number, presence: true, uniqueness: { scope: :tuner_job_id }

    enum status: {
      pending: "pending",
      running: "running",
      success: "success",
      failed: "failed",
    }
  end
end
