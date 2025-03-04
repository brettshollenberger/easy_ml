class AddWorkflowStatusToEasyMLDatasetHistories < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:easy_ml_dataset_histories, :workflow_status)
      add_column :easy_ml_dataset_histories, :workflow_status, :string
      add_index :easy_ml_dataset_histories, :workflow_status
    end

    unless column_exists?(:easy_ml_feature_histories, :workflow_status)
      add_column :easy_ml_feature_histories, :workflow_status, :string
      add_index :easy_ml_feature_histories, :workflow_status
    end
  end
end
