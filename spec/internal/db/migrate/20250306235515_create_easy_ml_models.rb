# lib/railtie/generators/templates/migration/create_easy_ml_models.rb.tt
class CreateEasyMLModels < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:easy_ml_models)
      create_table :easy_ml_models do |t|
        t.string :name, null: false
        t.string :model_type
        t.string :status
        t.bigint :dataset_id
        t.bigint :model_file_id
        t.json :configuration
        t.string :version, null: false
        t.string :root_dir
        t.json :file
        t.string :sha
        t.datetime :last_trained_at
        t.boolean :is_training

        t.timestamps

        t.index :created_at
        t.index :last_trained_at
        t.index :name
        t.index :version
        t.index :status
        t.index [:name, :status]
        t.index [:name, :version]
        t.index :dataset_id
        t.index :model_type
        t.index :model_file_id
        t.index :sha
        t.index :is_training
      end
    end
  end
end