class CreateEasyMLTunerRuns < ActiveRecord::Migration[7.2]
  def change
    create_table :easy_ml_tuner_runs do |t|
      t.bigint :easy_ml_model_id, null: false
      t.jsonb :hyperparameters
      t.bigint :group_id
      t.string :objective
      t.float :score
      t.jsonb :metadata
      t.timestamps

      t.index :easy_ml_model_id
      t.index :group_id
      t.index :objective
      t.index :created_at
    end
  end
end
