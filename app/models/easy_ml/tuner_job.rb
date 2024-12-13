# == Schema Information
#
# Table name: easy_ml_tuner_jobs
#
#  id                :bigint           not null, primary key
#  config            :json             not null
#  best_tuner_run_id :bigint
#  model_id          :bigint           not null
#  status            :string
#  direction         :string           default("minimize")
#  started_at        :datetime
#  completed_at      :datetime
#  metadata          :jsonb
#  wandb_url         :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
module EasyML
  class TunerJob < ActiveRecord::Base
    self.table_name = "easy_ml_tuner_jobs"

    belongs_to :model
    belongs_to :best_tuner_run, class_name: "EasyML::TunerRun", optional: true
    has_many :tuner_runs, dependent: :destroy

    validates :config, presence: true
    validates :direction, inclusion: { in: %w[minimize maximize] }

    enum status: {
      pending: "pending",
      running: "running",
      success: "success",
      failed: "failed",
    }

    def best_run
      return nil if tuner_runs.empty?

      tuner_runs.order(value: direction_order).first
    end

    def self.constants
      EasyML::Model::MODEL_OPTIONS.inject({}) do |h, (key, class_name)|
        h.tap do
          h[key] = class_name.constantize.hyperparameter_constants
        end
      end
    end

    private

    def direction_order
      direction == "minimize" ? :asc : :desc
    end
  end
end
