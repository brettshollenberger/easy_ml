class AddComputedColumnsToEasyMLColumns < ActiveRecord::Migration[7.2]
  def change
    add_column :easy_ml_columns, :computed_by, :string
    add_column :easy_ml_columns, :is_computed, :boolean, default: false
    
    add_index :easy_ml_columns, :computed_by
    add_index :easy_ml_columns, :is_computed
  end
end
