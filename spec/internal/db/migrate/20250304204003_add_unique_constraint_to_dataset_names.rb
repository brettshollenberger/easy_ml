class AddUniqueConstraintToDatasetNames < ActiveRecord::Migration[7.2]
  def change
    if index_exists?(:easy_ml_datasets, :name)
      remove_index :easy_ml_datasets, :name
    end
    add_index :easy_ml_datasets, :name, unique: true

    if index_exists?(:easy_ml_dataset_histories, :name)
      remove_index :easy_ml_dataset_histories, :name
    end
    add_index :easy_ml_dataset_histories, :name, unique: true
  end
end