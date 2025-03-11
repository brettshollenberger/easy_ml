class RemovePreprocessorStatisticsFromEasyMLDatasets < ActiveRecord::Migration[7.2]
  def change
    if column_exists?(:easy_ml_datasets, :preprocessor_statistics)
      remove_column :easy_ml_datasets, :preprocessor_statistics
    end

    if column_exists?(:easy_ml_dataset_histories, :preprocessor_statistics)
      remove_column :easy_ml_dataset_histories, :preprocessor_statistics
    end
  end
end