# == Schema Information
#
# Table name: easy_ml_retraining_jobs
#
#  id               :bigint           not null, primary key
#  model_id         :bigint
#  frequency        :string           not null
#  at               :json             not null
#  evaluator        :json
#  tuner_config     :json
#  tuning_frequency :string
#  last_tuning_at   :datetime
#  active           :boolean          default(TRUE)
#  status           :string           default("pending")
#  last_run_at      :datetime
#  locked_at        :datetime
#  metric           :string           not null
#  direction        :string           not null
#  threshold        :float            not null
#  auto_deploy      :boolean          default(FALSE)
#  batch_mode       :boolean
#  batch_size       :integer
#  batch_overlap    :integer
#  batch_key        :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
module EasyML
  class RetrainingJob < ActiveRecord::Base
    self.table_name = "easy_ml_retraining_jobs"

    include EasyML::Concerns::Lockable

    has_many :retraining_runs, class_name: "EasyML::RetrainingRun", dependent: :destroy
    has_many :tuner_jobs, through: :retraining_runs

    belongs_to :model, class_name: "EasyML::Model", inverse_of: :retraining_job
    validates :model, presence: true,
                      uniqueness: { message: "already has a retraining job" }

    VALID_FREQUENCIES = %w[day week month always].freeze
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
    validates :frequency, presence: true, inclusion: { in: VALID_FREQUENCIES }
    validates :metric, presence: true
    validate :validate_metrics_allowed
    validates :status, presence: true
    validates :at, presence: true
    validates :threshold, presence: true
    validates :tuning_frequency, inclusion: {
                                   in: VALID_FREQUENCIES,
                                   allow_nil: true,
                                 }
    validate :evaluator_must_be_valid
    validate :validate_at_format
    after_initialize :set_direction, unless: :persisted?

    scope :active, -> { where(active: true) }

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

    def tuner_config
      (read_attribute(:tuner_config) || {}).merge!(objective: metric).stringify_keys
    end

    def formatted_frequency
      if active
        FREQUENCY_TYPES.find { |type| type[:value] == frequency }[:label]
      else
        "Manually"
      end
    end

    def should_run?
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
      return false unless tuning_enabled
      return false unless tuning_frequency.present?
      return true if last_tuning_at.nil?

      case tuning_frequency
      when "always"
        true
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

    def metric=(metric)
      write_attribute(:metric, metric)
      set_direction
    end

    def evaluator
      {
        metric: metric,
        max: direction == "maximize" ? threshold : nil,
        min: direction == "minimize" ? threshold : nil,
        direction: direction,
      }.compact
    end

    def formatted_frequency
      {
        month: "Monthly",
        week: "Weekly",
        day: "Daily",
      }[frequency.to_sym]
    end

    private

    def metric_class
      return nil unless metric

      EasyML::Core::ModelEvaluator.get(metric).new
    end

    def set_direction
      return unless metric_class.present?

      write_attribute(:direction, metric_class.direction)
    end

    def validate_at_format
      return errors.add(:at, "must be a hash") unless at.is_a?(Hash)
      return if VALID_FREQUENCIES.exclude?(frequency.to_s)

      required_keys = case frequency
        when "day"
          ["hour"]
        when "week"
          ["hour", "day_of_week"]
        when "month"
          ["hour", "day_of_month"]
        end

      defaults = {
        "hour" => 0,
        "day_of_week" => 0, # Sunday
        "day_of_month" => 1,
      }

      missing_keys = required_keys - at.keys.map(&:to_s)
      missing_keys.each do |key|
        at[key] = defaults[key]
      end

      return if at.blank?

      allowed_keys = case frequency
        when "day"
          ["hour"]
        when "week"
          ["hour", "day_of_week"]
        when "month"
          ["hour", "day_of_month"]
        end

      self.at = self.at.select { |k, v| allowed_keys.include?(k.to_s) }.to_h

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

    def validate_metrics_allowed
      metric_unknown = EasyML::Core::ModelEvaluator.metrics.exclude?(metric.to_sym)
      return unless metric_unknown

      errors.add(:metrics,
                 "don't know how to handle metric #{metric}, use EasyML::Core::ModelEvaluator.register(:name, Evaluator, :regression|:classification)")
    end
  end
end
