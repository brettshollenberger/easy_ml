class AddIsDateColumnToEasyMLColumns < ActiveRecord::Migration[7.0]
  def change
    add_column :easy_ml_columns, :is_date_column, :boolean, default: false
  end
end
