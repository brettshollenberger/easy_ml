class AddIsDateColumnToEasyMLColumns < ActiveRecord::Migration[7.0]
  def change
    unless column_exists?(:easy_ml_columns, :is_date_column)
      add_column :easy_ml_columns, :is_date_column, :boolean, default: false
      add_index :easy_ml_columns, :is_date_column
    end
    
    unless column_exists?(:easy_ml_column_histories, :is_date_column)
      add_column :easy_ml_column_histories, :is_date_column, :boolean, default: false
      add_index :easy_ml_column_histories, :is_date_column
    end
  end
end
