class AddWorkflowStatusToEasyMLFeatures < ActiveRecord::Migration[7.2]
  def change
    add_column :easy_ml_features, :workflow_status, :string
    add_index :easy_ml_features, :workflow_status
  end
end
