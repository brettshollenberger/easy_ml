class AddShaToDatasourcesDatasetsAndColumns < ActiveRecord::Migration[7.2]
  def change
    add_column :easy_ml_datasources, :sha, :string
    add_column :easy_ml_datasets, :last_datasource_sha, :string

    add_index :easy_ml_datasources, :sha
    add_index :easy_ml_datasets, :last_datasource_sha

    add_column :easy_ml_datasource_histories, :sha, :string
    add_index :easy_ml_datasource_histories, :sha

    add_column :easy_ml_dataset_histories, :last_datasource_sha, :string
    add_index :easy_ml_dataset_histories, :last_datasource_sha

    add_column :easy_ml_columns, :last_datasource_sha, :string
    add_index :easy_ml_columns, :last_datasource_sha

    add_column :easy_ml_column_histories, :last_datasource_sha, :string
    add_index :easy_ml_column_histories, :last_datasource_sha
  end
end