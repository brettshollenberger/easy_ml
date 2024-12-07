# == Schema Information
#
# Table name: easy_ml_retraining_jobs
#
#  id               :bigint           not null, primary key
#  model_id         :bigint
#  frequency        :string           not null
#  at               :integer          not null
#  evaluator        :json
#  tuner_config     :json
#  tuning_frequency :string
#  last_tuning_at   :datetime
#  active           :boolean          default(TRUE)
#  status           :string           default("pending")
#  last_run_at      :datetime
#  locked_at        :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
module EasyML
  class RetrainingJob < ActiveRecord::Base
    self.table_name = "easy_ml_retraining_jobs"

    has_many :retraining_runs, dependent: :destroy
    has_many :tuner_jobs, through: :retraining_runs

    belongs_to :model, class_name: "EasyML::Model", inverse_of: :retraining_job
    validates :model, presence: true,
                      uniqueness: { message: "already has a retraining job" }

    FREQUENCY_TYPES = [
      {
        value: "day",
        label: "Daily",
        description: "Run once every day",
      },
      {
        value: "week",
        label: "Weekly",
        description: "Run once every week",
      },
      {
        value: "month",
        label: "Monthly",
        description: "Run once every month",
      },
    ].freeze
    validates :frequency, presence: true, inclusion: { in: %w[day week month] }
    validates :status, presence: true
    validates :at, presence: true,
                   numericality: { only_integer: true,
                                   greater_than_or_equal_to: 0,
                                   less_than: 24 }
    validates :tuning_frequency, inclusion: {
                                   in: %w[day week month],
                                   allow_nil: true,
                                 }
    validate :evaluator_must_be_valid

    scope :active, -> { where(active: true) }
    scope :locked, lambda {
      where("locked_at IS NOT NULL AND locked_at > ?", LOCK_TIMEOUT.ago)
    }

    scope :unlocked, lambda {
      where("locked_at IS NULL OR locked_at <= ?", LOCK_TIMEOUT.ago)
    }

    def self.current
      active.unlocked.select do |job|
        job.should_run?
      end
    end

    def self.constants
      {
        frequency: FREQUENCY_TYPES,
      }
    end

    def should_run?
      return false if locked?
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

    def should_tune?
      return false unless tuning_frequency.present?
      return true if last_tuning_at.nil?

      case tuning_frequency
      when "hour"
        last_tuning_at < Time.current.beginning_of_hour
      when "day"
        current_time = Time.current
        current_time.hour == at && last_tuning_at < current_time.beginning_of_day
      when "week"
        current_time = Time.current
        current_time.hour == at && current_time.wday == 0 && last_tuning_at < current_time.beginning_of_week
      when "month"
        current_time = Time.current
        current_time.hour == at && current_time.day == 1 && last_tuning_at < current_time.beginning_of_month
      end
    end

    def locked?
      return false if locked_at.nil?
      return false if locked_at < LOCK_TIMEOUT.ago

      true
    end

    def lock!
      return false if locked?

      update!(locked_at: Time.current)
    end

    def unlock!
      update!(locked_at: nil)
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

    LOCK_TIMEOUT = 6.hours

    def evaluator_must_be_valid
      return if evaluator.nil? || evaluator.blank?

      evaluator = self.evaluator.symbolize_keys

      unless evaluator[:metric].present? && (evaluator[:min].present? || evaluator[:max].present?)
        errors.add(:evaluator, "must specify metric and either min or max value")
        return
      end

      errors.add(:evaluator, "min value must be numeric") if evaluator[:min].present? && !evaluator[:min].is_a?(Numeric)

      errors.add(:evaluator, "max value must be numeric") if evaluator[:max].present? && !evaluator[:max].is_a?(Numeric)

      metric = evaluator[:metric].to_sym

      evaluator = EasyML::Core::ModelEvaluator.get(metric)
      unless evaluator.present?
        allowed_metrics = EasyML::Core::ModelEvaluator.metrics
        errors.add(:evaluator, "contains invalid metric. Allowed metrics are #{allowed_metrics}")
        return
      end

      return unless evaluator.present?
      return if evaluator.new.respond_to?(:evaluate)

      errors.add(:evaluator, "evaluator must implement evaluate method")
    end
  end
end
