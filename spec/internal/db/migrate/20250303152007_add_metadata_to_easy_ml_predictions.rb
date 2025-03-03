class AddMetadataToEasyMLPredictions < ActiveRecord::Migration[7.2]
  def change
    add_column :easy_ml_predictions, :metadata, :jsonb, default: {}, null: false
    add_index :easy_ml_predictions, :metadata, using: :gin
  end
end
