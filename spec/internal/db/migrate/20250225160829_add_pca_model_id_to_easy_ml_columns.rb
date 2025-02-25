class AddPCAModelIdToEasyMLColumns < ActiveRecord::Migration[7.2]
  def change
    add_column :easy_ml_columns, :pca_model_id, :integer
    add_index :easy_ml_columns, :pca_model_id

    add_column :easy_ml_column_histories, :pca_model_id, :integer
    add_index :easy_ml_column_histories, :pca_model_id
  end
end