class CreateEasyMLDatasetStatistics < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_dataset_statistics do |t|
      t.bigint :easy_ml_dataset_id
      t.json :statistics
      t.timestamps

      t.index :created_at
      t.index :easy_ml_dataset_id
    end
  end
end