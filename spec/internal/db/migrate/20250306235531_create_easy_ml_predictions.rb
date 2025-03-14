class CreateEasyMLPredictions < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:easy_ml_predictions)
      create_table :easy_ml_predictions do |t|
        t.bigint :model_id, null: false
        t.bigint :model_history_id
        t.string :prediction_type
        t.jsonb :prediction_value
        t.jsonb :raw_input
        t.jsonb :normalized_input
        t.timestamps

        t.index :model_id
        t.index :model_history_id
        t.index :created_at
      end
    end
  end
end
