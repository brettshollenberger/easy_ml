class AddLastFeatureShaToColumns < ActiveRecord::Migration[7.2]
  def change
    add_column :easy_ml_columns, :last_feature_sha, :string
    add_index :easy_ml_columns, :last_feature_sha

    add_column :easy_ml_column_histories, :last_feature_sha, :string
    add_index :easy_ml_column_histories, :last_feature_sha
  end
end