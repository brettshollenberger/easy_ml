class CreateEasyMLRetrainingJobs < ActiveRecord::Migration[7.0]
  def change
    create_table :easy_ml_retraining_jobs do |t|
      t.bigint :model_id
      t.string :frequency, null: false  # day, week, month, hour
      t.json :at, null: false           # hour of day (0-23)
      t.json :evaluator                 # Model evaluator
      t.json :tuner_config              # configuration for the tuner
      t.string :tuning_frequency        # day, week, month, hour - when to run with tuner
      t.datetime :last_tuning_at        # track last tuning run
      t.boolean :active, default: true
      t.string :status, default: "pending"
      t.datetime :last_run_at
      t.datetime :locked_at
      t.string :metric, null: false
      t.string :direction, null: false
      t.float :threshold, null: false

      t.timestamps

      t.index :model_id
      t.index :active
      t.index :last_run_at
      t.index :last_tuning_at
      t.index :locked_at
    end

    create_table :easy_ml_retraining_runs do |t|
      t.bigint :model_id
      t.bigint :retraining_job_id, null: false
      t.bigint :tuner_job_id, null: true
      t.string :status, default: 'pending'
      t.float :metric_value
      t.float :threshold
      t.string :threshold_direction
      t.boolean :should_promote
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message
      t.jsonb :metadata
      t.jsonb :metrics

      t.timestamps

      t.index :status
      t.index :started_at
      t.index :completed_at
      t.index :created_at
      t.index :tuner_job_id
      t.index :retraining_job_id
      t.index :model_id
    end
  end
end
