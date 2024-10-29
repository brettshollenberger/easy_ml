# == Schema Information
#
# Table name: easy_ml_retraining_runs
#
#  id                  :bigint           not null, primary key
#  model_id            :bigint
#  retraining_job_id   :bigint           not null
#  tuner_job_id        :bigint
#  status              :string           default("pending")
#  metric_value        :float
#  threshold           :float
#  threshold_direction :string
#  should_promote      :boolean
#  started_at          :datetime
#  completed_at        :datetime
#  error_message       :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
module EasyML
  class RetrainingRun < ActiveRecord::Base
    self.table_name = "easy_ml_retraining_runs"

    belongs_to :retraining_job
    belongs_to :model, class_name: "EasyML::Model"

    validates :status, presence: true, inclusion: { in: %w[pending running completed failed] }

    def perform_retraining!
      return false unless pending?

      begin
        update!(status: "running", started_at: Time.current)

        # Only use tuner if tuning frequency has been met
        binding.pry # Merge in retraining_job.evaluator to model, which uses currently a symbol instead of hash
        if should_tune?
          training_model = Orchestrator.train(retraining_job.model, tuner: retraining_job.tuner_config)
          retraining_job.update!(last_tuning_at: Time.current)
        else
          training_model = Orchestrator.train(retraining_job.model)
        end

        results = metric_results(training_model)
        training_model.promote if results[:should_promote]

        update!(
          results.merge!(
            status: training_model.inference? ? "completed" : "failed",
            completed_at: training_model.inference? ? Time.current : nil,
            error_message: training_model.inference? ? nil : "Did not pass evaluation",
            model: training_model
          )
        )

        retraining_job.update!(last_run_at: Time.current)
        true
      rescue StandardError => e
        30.times do
          p e
        end
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

    private

    def should_tune?
      retraining_job.tuner_config.present? && retraining_job.should_tune?
    end

    def metric_results(training_model)
      return training_model.promotable? unless retraining_job.evaluator.present?

      training_model.dataset.refresh
      evaluator = retraining_job.evaluator.symbolize_keys
      x_true, y_true = training_model.dataset.test(split_ys: true)
      y_pred = training_model.predict(x_true)

      metric = evaluator[:metric].to_sym
      metrics = EasyML::Core::ModelEvaluator.evaluate(
        model: training_model,
        y_pred: y_pred,
        y_true: y_true,
        evaluator: evaluator
      )
      metric_value = metrics[metric]

      # Check against min threshold if present
      if evaluator[:min].present?
        threshold = evaluator[:min]
        threshold_direction = "min"
        should_promote = metric_value > threshold
      else
        threshold = evaluator[:max]
        threshold_direction = "max"
        should_promote = metric_value < threshold
      end

      {
        metric_value: metric_value,
        threshold: threshold,
        threshold_direction: threshold_direction,
        should_promote: should_promote
      }
    end
  end
end
