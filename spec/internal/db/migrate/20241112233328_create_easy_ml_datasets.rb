class CreateEasyMLDatasets < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_datasets do |t|
      t.string :name, null: false
      t.string :description
      t.string :dataset_type
      t.string :status
      t.string :version
      t.bigint :datasource_id
      t.string :root_dir
      t.json :configuration
      t.bigint :num_rows
      t.string :workflow_status
      t.json :statistics
      t.json :schema

      t.timestamps

      t.index :created_at
      t.index :name
      t.index :status
      t.index [:name, :status]
      t.index :datasource_id
      t.index :dataset_type
      t.index :workflow_status
    end
  end
end