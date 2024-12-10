class CreateEasyMLModelFiles < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_model_files do |t|
      t.string :filename, null: false
      t.string :path, null: false
      t.json :configuration
      t.string :model_type
      t.bigint :model_id
      t.bigint :retraining_run_id
      t.timestamps
      t.datetime :deployed_at
      t.boolean :deployed

      t.index :created_at
      t.index :filename
      t.index [:model_type]
      t.index :model_id
      t.index :retraining_run_id
      t.index :deployed_at
      t.index :deployed
    end
  end
end