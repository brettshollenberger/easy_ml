class AddLearnedAtToEasyMLColumns < ActiveRecord::Migration[7.2]
  def change
    add_column :easy_ml_columns, :learned_at, :timestamp
    add_column :easy_ml_columns, :is_learning, :boolean, default: false
    add_index :easy_ml_columns, :learned_at
    add_index :easy_ml_columns, :is_learning

    add_column :easy_ml_column_histories, :learned_at, :timestamp
    add_column :easy_ml_column_histories, :is_learning, :boolean, default: false
    add_index :easy_ml_column_histories, :learned_at
    add_index :easy_ml_column_histories, :is_learning
  end
end