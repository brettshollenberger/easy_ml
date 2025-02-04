class AddLearnedAtToEasyMLColumns < ActiveRecord::Migration[7.2]
  def change
    add_column :easy_ml_columns, :learned_at, :timestamp
    add_index :easy_ml_columns, :learned_at
    
    add_column :easy_ml_column_histories, :learned_at, :timestamp
    add_index :easy_ml_column_histories, :learned_at
  end
end