class AddViewClassToEasyMLDatasets < ActiveRecord::Migration[7.2]
  def change
    add_column :easy_ml_datasets, :view_class, :string
    add_index :easy_ml_datasets, :view_class

    add_column :easy_ml_dataset_histories, :view_class, :string
    add_index :easy_ml_dataset_histories, :view_class
  end
end
