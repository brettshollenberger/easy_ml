# lib/railtie/generators/templates/migration/create_easy_ml_models.rb.tt
class CreateEasyMLModels < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_models do |t|
      t.string :name, null: false
      t.string :model_type
      t.bigint :dataset_id
      t.json :configuration
      t.boolean :is_live, default: false
      t.string :version, null: false
      t.json :file, null: false

      t.timestamps

      t.index :created_at
      t.index :name
      t.index :version
      t.index :is_live
      t.index [:name, :version], unique: true
      t.index [:name, :version, :is_live]
      t.index :dataset_id
      t.index :model_type
    end
  end
end