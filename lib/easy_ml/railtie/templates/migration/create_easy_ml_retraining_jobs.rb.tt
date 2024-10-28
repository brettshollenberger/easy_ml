class CreateEasyMLRetrainingJobs < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_retraining_jobs do |t|
      t.string :model, null: false  
      t.string :frequency, null: false  # day, week, month, hour
      t.integer :at, null: false        # hour of day (0-23)
      t.json :tuner_config              # configuration for the tuner
      t.boolean :active, default: true
      t.string :status, default: "pending"
      t.datetime :last_run_at
      t.datetime :locked_at

      t.timestamps

      t.index :model
      t.index :active
      t.index :last_run_at
      t.index :locked_at
    end

    create_table :easy_ml_retraining_runs do |t|
      t.references :retraining_job, null: false
      t.references :tuner_job, null: true
      t.string :status, default: 'pending'
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message

      t.timestamps

      t.index :status
      t.index :started_at
      t.index :completed_at
      t.index :created_at
    end
  end
end
