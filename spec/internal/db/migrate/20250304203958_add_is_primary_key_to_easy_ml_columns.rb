class AddIsPrimaryKeyToEasyMLColumns < ActiveRecord::Migration[7.2]
  def change
    add_column :easy_ml_columns, :is_primary_key, :boolean
    add_index :easy_ml_columns, :is_primary_key

    add_column :easy_ml_column_histories, :is_primary_key, :boolean
    add_index :easy_ml_column_histories, :is_primary_key
  end
end
