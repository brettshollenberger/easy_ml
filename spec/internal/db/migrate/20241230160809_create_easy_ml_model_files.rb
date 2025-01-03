class CreateEasyMLModelFiles < ActiveRecord::Migration[7.2]
  def change
    create_table :easy_ml_model_files do |t|
      t.string :filename, null: false
      t.string :path, null: false
      t.json :configuration
      t.string :model_type
      t.bigint :model_id
      t.timestamps

      t.index :created_at
      t.index :filename
      t.index [:model_type]
      t.index :model_id
    end
  end
end