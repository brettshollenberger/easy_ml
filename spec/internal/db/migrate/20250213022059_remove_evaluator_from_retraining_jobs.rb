class RemoveEvaluatorFromRetrainingJobs < ActiveRecord::Migration[7.2]
  def change
    if column_exists?(:easy_ml_retraining_jobs, :evaluator)
      remove_column :easy_ml_retraining_jobs, :evaluator
    end
  end
end