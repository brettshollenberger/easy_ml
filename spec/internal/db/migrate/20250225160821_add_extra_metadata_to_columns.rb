class AddExtraMetadataToColumns < ActiveRecord::Migration[7.2]
  def change
    add_column :easy_ml_columns, :in_raw_dataset, :boolean
    add_index :easy_ml_columns, :in_raw_dataset

    add_column :easy_ml_column_histories, :in_raw_dataset, :boolean
    add_index :easy_ml_column_histories, :in_raw_dataset
  end
end