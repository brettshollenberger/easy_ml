class CreateEasyMLRetrainingJobs < ActiveRecord::Migration[7.0]
  def change
    create_table :easy_ml_retraining_jobs do |t|
      t.bigint :model_id
      t.string :frequency, null: false  # day, week, month, hour
      t.json :at, null: false           # hour of day (0-23)
      t.json :evaluator                 # Model evaluator
      t.boolean :tuning_enabled, default: false
      t.json :tuner_config              # configuration for the tuner
      t.string :tuning_frequency        # day, week, month, hour - when to run with tuner
      t.datetime :last_tuning_at        # track last tuning run
      t.boolean :active, default: true
      t.string :status, default: "pending"
      t.datetime :last_run_at
      t.string :metric, null: false
      t.string :direction, null: false
      t.float :threshold, null: false
      t.boolean :auto_deploy, default: false
      t.boolean :batch_mode
      t.integer :batch_size
      t.integer :batch_overlap
      t.string :batch_key

      t.timestamps

      t.index :model_id
      t.index :active
      t.index :last_run_at
      t.index :last_tuning_at
      t.index :batch_mode
      t.index :auto_deploy
      t.index :tuning_enabled
    end

    create_table :easy_ml_retraining_runs do |t|
      t.bigint :model_id
      t.bigint :model_history_id
      t.bigint :retraining_job_id, null: false
      t.bigint :tuner_job_id, null: true
      t.string :status, default: 'pending'
      t.float :metric_value
      t.float :threshold
      t.string :trigger, default: 'manual'
      t.string :threshold_direction
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message
      t.jsonb :metadata
      t.jsonb :metrics
      t.jsonb :best_params
      t.string :wandb_url
      t.string :snapshot_id
      t.boolean :deployable
      t.boolean :is_deploying
      t.boolean :deployed
      t.bigint :deploy_id

      t.timestamps

      t.index :status
      t.index :started_at
      t.index :completed_at
      t.index :created_at
      t.index :tuner_job_id
      t.index :retraining_job_id
      t.index :model_id
      t.index :trigger
      t.index :wandb_url
      t.index :snapshot_id
      t.index :deploy_id
      t.index :model_history_id
      t.index :deployable
      t.index :is_deploying
    end
  end
end
