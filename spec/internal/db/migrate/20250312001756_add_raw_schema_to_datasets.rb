class AddRawSchemaToDatasets < ActiveRecord::Migration[7.2]
  def change
    add_column :easy_ml_datasets, :raw_schema, :jsonb
    add_index :easy_ml_datasets, :raw_schema

    add_column :easy_ml_dataset_histories, :raw_schema, :jsonb
    add_index :easy_ml_dataset_histories, :raw_schema
  end
end