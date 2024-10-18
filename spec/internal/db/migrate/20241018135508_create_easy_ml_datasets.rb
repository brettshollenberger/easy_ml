class CreateEasyMLDatasets < ActiveRecord::Migration[7.2]
  def change
    create_table :easy_ml_datasets do |t|
      t.string :name, null: false
      t.bigint :easy_ml_datasource_id, null: false
      t.string :target, null: false
      t.string :drop_if_null, array: true
      t.string :drop_cols, array: true
      t.jsonb :polars_args
      t.jsonb :splitter
      t.jsonb :preprocessing_steps
      t.timestamps
    end

    add_index :easy_ml_datasets, :name, unique: true
  end
end
