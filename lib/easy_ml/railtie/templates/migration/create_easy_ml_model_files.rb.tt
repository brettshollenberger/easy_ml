class CreateEasyMLModelFiles < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_model_files do |t|
      t.string :filename, null: false
      t.string :path, null: false
      t.bigint :model_id
      t.json :configuration
      t.timestamps

      t.index :created_at
      t.index :filename
      t.index :model_id
    end
  end
end