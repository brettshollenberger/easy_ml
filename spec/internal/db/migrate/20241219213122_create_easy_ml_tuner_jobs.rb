class CreateEasyMLTunerJobs < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_tuner_jobs do |t|
      t.json :config, null: false
      t.bigint :best_tuner_run_id
      t.bigint :model_id, null: false
      t.string :status
      t.string :direction, default: 'minimize'
      t.datetime :started_at
      t.datetime :completed_at
      t.jsonb :metadata
      t.string :wandb_url

      t.timestamps

      t.index :status
      t.index :started_at
      t.index :completed_at
      t.index :model_id
      t.index :best_tuner_run_id
      t.index :wandb_url
    end

    create_table :easy_ml_tuner_runs do |t|
      t.bigint :tuner_job_id, null: false
      t.json :hyperparameters, null: false
      t.float :value
      t.integer :trial_number
      t.string :status
      t.string :wandb_url

      t.timestamps

      t.index [:tuner_job_id, :value]
      t.index [:tuner_job_id, :trial_number], name: "idx_tuner_runs_and_trial_number"
      t.index :status
      t.index :wandb_url
    end
  end
end
