class CreateEasyMLDatasets < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_datasets do |t|
      t.string :name, null: false
      t.string :status
      t.string :version
      t.bigint :datasource_id
      t.string :root_dir
      
      t.boolean :verbose, default: false
      t.date :today
      t.string :target, null: false
      t.integer :batch_size, default: 50_000
      t.json :drop_if_null
      t.json :polars_args
      t.string :transforms
      t.json :drop_cols
      t.json :preprocessing_steps

      t.timestamps

      t.index :created_at
      t.index :name
      t.index :status
      t.index [:name, :status]
      t.index :datasource_id
    end
  end
end