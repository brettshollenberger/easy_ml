# == Schema Information
#
# Table name: easy_ml_retraining_jobs
#
#  id               :bigint           not null, primary key
#  model_id         :bigint
#  frequency        :string           not null
#  at               :json
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

    has_many :retraining_runs, class_name: "EasyML::RetrainingRun", dependent: :destroy
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
    validates :at, presence: true
    validates :tuning_frequency, inclusion: {
                                   in: %w[day week month],
                                   allow_nil: true,
                                 }
    validate :evaluator_must_be_valid
    validate :validate_at_format

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

      case frequency
      when "day"
        current_time = Time.current
        return false if last_run_at.to_date == current_time.to_date
        current_time.hour == at["hour"]
      when "week"
        current_time = Time.current
        return false if last_run_at.to_date >= current_time.beginning_of_week
        current_time.wday == at["day_of_week"] && current_time.hour == at["hour"]
      when "month"
        current_time = Time.current
        return false if last_run_at.to_date >= current_time.beginning_of_month
        current_time.day == at["day_of_month"] && current_time.hour == at["hour"]
      else
        false
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
        current_time.hour == at["hour"] && last_tuning_at < current_time.beginning_of_day
      when "week"
        current_time = Time.current
        current_time.hour == at["hour"] && current_time.wday == 0 && last_tuning_at < current_time.beginning_of_week
      when "month"
        current_time = Time.current
        current_time.hour == at["hour"] && current_time.day == 1 && last_tuning_at < current_time.beginning_of_month
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

    def validate_at_format
      return if at.blank?
      return errors.add(:at, "must be a hash") unless at.is_a?(Hash)

      required_keys = case frequency
        when "day"
          ["hour"]
        when "week"
          ["hour", "day_of_week"]
        when "month"
          ["hour", "day_of_month"]
        end

      missing_keys = required_keys - at.keys.map(&:to_s)
      errors.add(:at, "missing required keys: #{missing_keys.join(", ")}") if missing_keys.any?

      # Validate no extra keys are present
      allowed_keys = case frequency
        when "day"
          ["hour"]
        when "week"
          ["hour", "day_of_week"]
        when "month"
          ["hour", "day_of_month"]
        end

      extra_keys = at.keys.map(&:to_s) - allowed_keys
      errors.add(:at, "unexpected keys for #{frequency} frequency: #{extra_keys.join(", ")}") if extra_keys.any?

      if at["hour"].present?
        errors.add(:at, "hour must be between 0 and 23") unless (0..23).include?(at["hour"].to_i)
      end

      if at["day_of_week"].present?
        errors.add(:at, "day_of_week must be between 0 and 6") unless (0..6).include?(at["day_of_week"].to_i)
      end

      if at["day_of_month"].present?
        errors.add(:at, "day_of_month must be between 1 and 31") unless (1..31).include?(at["day_of_month"].to_i)
      end
    end

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
