class CreateEasyMLModelFiles < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_model_files do |t|
      t.string :filename, null: false
      t.string :path, null: false
      t.json :configuration
      t.bigint :model_id
      t.string :model_type
      t.timestamps

      t.index :created_at
      t.index :filename
      t.index [:model_id, :model_type]
    end
  end
end