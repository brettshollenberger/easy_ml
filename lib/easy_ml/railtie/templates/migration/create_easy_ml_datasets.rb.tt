class CreateEasyMLDatasets < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_datasets do |t|
      t.string :name, null: false
      t.string :status
      t.string :version
      t.bigint :datasource_id
      t.string :root_dir
      t.json :configuration
      t.boolean :verbose, default: false
      t.date :today
      t.string :target, null: false
      t.integer :batch_size, default: 50000
      t.string :drop_if_null, array: true, default: [], null: false
      t.json :polars_args, default: {}
      t.string :drop_cols, array: true, default: [], null: false
      t.json :preprocessing_steps, default: {}
      t.json :splitter
      t.string :transforms

      t.timestamps

      t.index :created_at
      t.index :name
      t.index :status
      t.index [:name, :status]
      t.index :datasource_id
    end
  end
end