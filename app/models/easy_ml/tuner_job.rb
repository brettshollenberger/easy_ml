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
      completed: "completed",
      failed: "failed"
    }

    def best_run
      return nil if tuner_runs.empty?

      tuner_runs.order(value: direction_order).first
    end

    private

    def direction_order
      direction == "minimize" ? :asc : :desc
    end
  end
end
