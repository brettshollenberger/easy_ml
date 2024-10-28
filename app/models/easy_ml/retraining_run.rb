# == Schema Information
#
# Table name: easy_ml_retraining_runs
#
#  id                :bigint           not null, primary key
#  retraining_job_id :bigint           not null
#  tuner_job_id      :bigint
#  status            :string           default("pending")
#  started_at        :datetime
#  completed_at      :datetime
#  error_message     :text
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
module EasyML
  class RetrainingRun < ActiveRecord::Base
    self.table_name = "easy_ml_retraining_runs"

    belongs_to :retraining_job
    has_one :tuner_job, dependent: :destroy

    validates :status, presence: true, inclusion: { in: %w[pending running completed failed] }

    def perform_retraining!
      return false unless pending?

      begin
        update!(status: "running", started_at: Time.current)

        # Train with tuner config if present
        training_model = if retraining_job.tuner_config.present?
                           Orchestrator.train(retraining_job.model, tuner: retraining_job.tuner_config)
                         else
                           Orchestrator.train(retraining_job.model)
                         end

        # Promote the model if training was successful
        training_model.promote if training_model.promotable?

        update!(
          status: "completed",
          completed_at: Time.current,
          error_message: nil
        )

        retraining_job.update!(last_run_at: Time.current)
        true
      rescue StandardError => e
        update!(
          status: "failed",
          completed_at: Time.current,
          error_message: e.message
        )
        false
      end
    end

    def pending?
      status == "pending"
    end

    def completed?
      status == "completed"
    end

    def failed?
      status == "failed"
    end

    def running?
      status == "running"
    end
  end
end
