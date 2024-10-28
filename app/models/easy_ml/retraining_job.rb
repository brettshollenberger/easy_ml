module EasyML
  class RetrainingJob < ActiveRecord::Base
    self.table_name = "easy_ml_retraining_jobs"

    has_many :retraining_runs, dependent: :destroy
    has_many :tuner_jobs, through: :retraining_runs

    validates :model, presence: true
    validates :frequency, presence: true, inclusion: { in: %w[hour day week month] }
    validates :status, presence: true
    validates :at, presence: true,
                   numericality: { only_integer: true,
                                   greater_than_or_equal_to: 0,
                                   less_than: 24 }

    scope :active, -> { where(active: true) }

    def self.current
      active.select do |job|
        job.should_run?
      end
    end

    def should_run?
      return true if last_run_at.nil?

      current_time = Time.current
      return false if retraining_runs.where("created_at > ?", current_period_start).exists?

      case frequency
      when "hour"
        last_run_at < current_time.beginning_of_hour
      when "day"
        current_time.hour == at && last_run_at < current_time.beginning_of_day
      when "week"
        current_time.hour == at && current_time.wday == 0 && last_run_at < current_time.beginning_of_week
      when "month"
        current_time.hour == at && current_time.day == 1 && last_run_at < current_time.beginning_of_month
      end
    end

    private

    def current_period_start
      current_time = Time.current
      case frequency
      when "hour"
        current_time.beginning_of_hour
      when "day"
        current_time.beginning_of_day
      when "week"
        current_time.beginning_of_week
      when "month"
        current_time.beginning_of_month
      end
    end
  end
end
