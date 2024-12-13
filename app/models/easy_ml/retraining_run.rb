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
#  trigger             :string           default("manual")
#  threshold_direction :string
#  deployable          :boolean
#  started_at          :datetime
#  completed_at        :datetime
#  error_message       :text
#  metadata            :jsonb
#  metrics             :jsonb
#  best_params         :jsonb
#  wandb_url           :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
module EasyML
  class RetrainingRun < ActiveRecord::Base
    self.table_name = "easy_ml_retraining_runs"

    belongs_to :retraining_job
    belongs_to :model, class_name: "EasyML::Model"
    has_many :events, as: :eventable, class_name: "EasyML::Event", dependent: :destroy

    validates :status, presence: true, inclusion: { in: %w[pending running success failed] }

    scope :running, -> { where(status: "running") }

    def wrap_training(&block)
      return false unless pending?

      begin
        EasyML::Event.create_event(self, "started")
        update!(status: "running", started_at: Time.current)

        training_model, best_params = yield

        if best_params.present?
          tuner = EasyML::TunerJob.where(model: training_model)
            .order(id: :desc)
            .first
        end

        results = metric_results(training_model)
        failed_reasons = training_model.cannot_deploy_reasons - ["Model has not changed"]
        if results[:deployable] == false
          status = "success"
        else
          status = failed_reasons.any? ? "failed" : "success"
        end

        update!(
          results.merge!(
            status: status,
            completed_at: failed_reasons.none? ? Time.current : nil,
            error_message: failed_reasons.any? ? failed_reasons&.first : nil,
            model: training_model,
            metrics: training_model.evaluate,
            best_params: best_params,
            tuner_job_id: tuner&.id,
            metadata: tuner&.metadata,
            wandb_url: tuner&.wandb_url,
          )
        )

        if failed_reasons.any?
          EasyML::Event.handle_error(self, failed_reasons.first)
        else
          EasyML::Event.create_event(self, status)
        end
        retraining_job.update!(last_run_at: Time.current)

        reload
        if deployable? && retraining_job.auto_deploy
          training_model.save_model_file
          training_model.reload
          EasyML::Deploy.create!(retraining_run: self, model: training_model, model_file: training_model.model_file, trigger: trigger)
        end
        true
      rescue StandardError => e
        EasyML::Event.handle_error(self, e)
        update!(
          status: "failed",
          completed_at: Time.current,
          error_message: e.message,
        )
        false
      end
    end

    def pending?
      status == "pending"
    end

    def success?
      status == "success"
    end

    def failed?
      status == "failed"
    end

    def running?
      status == "running"
    end

    def should_tune?
      retraining_job.tuner_config.present? && retraining_job.should_tune?
    end

    private

    def metric_results(training_model)
      return training_model.deployable? unless retraining_job.evaluator.present?

      training_model.dataset.refresh
      evaluator = retraining_job.evaluator.symbolize_keys
      x_true, y_true = training_model.dataset.test(split_ys: true)
      y_pred = training_model.predict(x_true)

      metric = evaluator[:metric].to_sym
      metrics = EasyML::Core::ModelEvaluator.evaluate(
        model: training_model,
        y_pred: y_pred,
        y_true: y_true,
        evaluator: evaluator,
      )
      metric_value = metrics[metric]

      # Check against min threshold if present
      if evaluator[:min].present?
        threshold = evaluator[:min]
        threshold_direction = "minimize"
        deployable = metric_value < threshold
      else
        threshold = evaluator[:max]
        threshold_direction = "maximize"
        deployable = metric_value > threshold
      end

      {
        metric_value: metric_value,
        threshold: threshold,
        threshold_direction: threshold_direction,
        deployable: deployable,
      }
    end
  end
end
