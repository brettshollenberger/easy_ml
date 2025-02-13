class AddComputedColumnsToEasyMLColumns < ActiveRecord::Migration[7.2]
  def change
    add_column :easy_ml_columns, :computed_by, :string
    add_column :easy_ml_columns, :is_computed, :boolean, default: false
    add_column :easy_ml_columns, :feature_id, :bigint
    
    add_index :easy_ml_columns, :computed_by
    add_index :easy_ml_columns, :is_computed
    add_index :easy_ml_columns, :feature_id

    add_column :easy_ml_column_histories, :computed_by, :string
    add_index :easy_ml_column_histories, :computed_by
    add_column :easy_ml_column_histories, :is_computed, :boolean, default: false
    add_index :easy_ml_column_histories, :is_computed
    add_column :easy_ml_column_histories, :feature_id, :bigint
    add_index :easy_ml_column_histories, :feature_id
  end
end
