class CreateEasyMLModels < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_models do |t|
      t.string :name, null: false
      t.boolean :is_live, default: false
      t.string :version, null: false
      t.string :ml_model
      t.string :task
      t.json :metrics, default: []
      t.json :file, null: false
      t.bigint :easy_ml_dataset_id
      t.jsonb :hyperparameters

      t.timestamps

      t.index :created_at
      t.index :name
      t.index :version
      t.index :is_live
      t.index [:name, :version], unique: true
      t.index [:name, :version, :is_live]
      t.index :easy_ml_dataset_id
    end
  end
end