class CreateEasyMLSplitters < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_splitters do |t|
      t.string :splitter_type, null: false
      t.json :configuration
      t.bigint :dataset_id, null: false

      t.timestamps

      t.index :splitter_type
      t.index :created_at
      t.index :dataset_id
    end
  end
end