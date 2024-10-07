# lib/railtie/generators/templates/migration/create_easy_ml_models.rb.tt
class CreateEasyMLModels < ActiveRecord::Migration[6.0]
  def change
    create_table :easy_ml_models do |t|
      t.string :version, null: false
      t.string :model
      t.string :task
      t.string :metrics, array: true
      t.string :file, null: false

      t.timestamps

      t.index :created_at
      t.index [:model, :version], unique: true
    end
  end
end