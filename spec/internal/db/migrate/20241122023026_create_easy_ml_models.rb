# lib/railtie/generators/templates/migration/create_easy_ml_models.rb.tt
class CreateEasyMLModels < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_models do |t|
      t.string :name, null: false
      t.string :model_type
      t.string :status
      t.bigint :dataset_id
      t.json :configuration
      t.string :version, null: false
      t.string :root_dir
      t.json :file

      t.timestamps

      t.index :created_at
      t.index :name
      t.index :version
      t.index :status
      t.index [:name, :status]
      t.index [:name, :version]
      t.index :dataset_id
      t.index :model_type
    end
  end
end