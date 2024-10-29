# == Schema Information
#
# Table name: easy_ml_retraining_jobs
#
#  id           :bigint           not null, primary key
#  model        :string           not null
#  frequency    :string           not null
#  at           :integer          not null
#  tuner_config :json
#  evaluator    :json
#  active       :boolean          default(TRUE)
#  status       :string           default("pending")
#  last_run_at  :datetime
#  locked_at    :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
module EasyML
  class RetrainingJob < ActiveRecord::Base
    self.table_name = "easy_ml_retraining_jobs"

    has_many :retraining_runs, dependent: :destroy
    has_many :tuner_jobs, through: :retraining_runs

    validates :model, presence: true,
                      uniqueness: { message: "already has a retraining job" }
    validate :model_must_exist
    validates :frequency, presence: true, inclusion: { in: %w[hour day week month] }
    validates :status, presence: true
    validates :at, presence: true,
                   numericality: { only_integer: true,
                                   greater_than_or_equal_to: 0,
                                   less_than: 24 }
    validates :tuning_frequency, inclusion: {
      in: %w[hour day week month],
      allow_nil: true
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

    def model_must_exist
      return if model.blank?
      return if EasyML::Model.where(name: model).inference.exists?

      errors.add(:model, "does not exist or is not in inference state")
    end

    def evaluator_must_be_valid
      return if evaluator.nil? || evaluator.blank?

      unless evaluator["metric"].present? && (evaluator["min"].present? || evaluator["max"].present?)
        errors.add(:evaluator, "must specify metric and either min or max value")
        return
      end

      if evaluator["min"].present? && !evaluator["min"].is_a?(Numeric)
        errors.add(:evaluator, "min value must be numeric")
      end

      if evaluator["max"].present? && !evaluator["max"].is_a?(Numeric)
        errors.add(:evaluator, "max value must be numeric")
      end

      metric = evaluator["metric"].to_sym
      valid_metrics = %i[rmse mae mse r2 accuracy precision recall f1 custom]

      unless valid_metrics.include?(metric)
        errors.add(:evaluator, "contains invalid metric")
        return
      end

      return unless metric == :custom

      unless evaluator["evaluator_class"].present?
        errors.add(:evaluator, "must specify evaluator_class for custom metric")
        return
      end

      begin
        evaluator_class = evaluator["evaluator_class"].constantize
        unless evaluator_class.respond_to?(:evaluate)
          errors.add(:evaluator, "evaluator_class must implement evaluate method")
        end
      rescue NameError
        errors.add(:evaluator, "evaluator_class does not exist")
      end
    end
  end
end
